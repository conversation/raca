require 'net/http'
require 'digest/md5'
require 'openssl'

module Raca
  # Handy abstraction for interacting with a single Cloud Files container. We
  # could use fog or similar, but this ~200 line class is simple and does
  # everything we need.
  class Bucket
    MAX_ITEMS_PER_LIST = 10_000
    LARGE_FILE_THRESHOLD = 5_368_709_120 # 5 Gb
    LARGE_FILE_SEGMENT_SIZE = 104_857_600 # 100 Mb

    attr_reader :bucket_name

    def initialize(account, bucket_name, opts = {})
      raise ArgumentError, "The bucket name must not contain '/'." if bucket_name['/']
      @account, @bucket_name = account, bucket_name
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    # Upload data_or_path (which may be a filename or an IO) to the bucket, as key.
    def upload(key, data_or_path)
      case data_or_path
      when StringIO, File
        upload_io(key, data_or_path, data_or_path.size)
      when String
        File.open(data_or_path, "rb") do |io|
          upload_io(key, io, io.stat.size)
        end
      else
        raise ArgumentError, "data_or_path must be an IO with data or filename string"
      end
    end

    # Delete +key+ from the container. If the container is on the CDN, the object will
    # still be served from the CDN until the TTL expires.
    def delete(key)
      log "deleting #{key} from #{bucket_path}"
      storage_request(Net::HTTP::Delete.new(File.join(bucket_path, key)))
    end

    # Remove +key+ from the CDN edge nodes on which it is currently cached. The object is
    # not deleted from the container: as the URL is re-requested, the edge cache will be
    # re-filled with the object currently in the container.
    #
    # This shouldn't be used except when it's really required (e.g. when a piece has to be
    # taken down) because it's expensive: it lodges a support ticket at Akamai. (!)
    def purge_from_akamai(key, email_address)
      log "Requesting #{File.join(bucket_path, key)} to be purged from the CDN"
      cdn_request(Net::HTTP::Delete.new(
        File.join(bucket_path, key),
        'X-Purge-Email' => email_address
      ))
    end

    def download(key, filepath)
      log "downloading #{key} from #{bucket_path}"
      storage_request(Net::HTTP::Get.new(File.join(bucket_path, key))) do |response|
        File.open(filepath, 'wb') do |io|
          response.read_body do |chunk|
            io.write(chunk)
          end
        end
      end
    end

    # Return an array of files in the bucket.
    #
    # Supported options
    #
    # max - the maximum number of items to return
    # marker - return items alphabetically after this key. Useful for pagination
    # prefix - only return items that start with this string
    def list(options = {})
      max = options.fetch(:max, MAX_ITEMS_PER_LIST)
      marker = options.fetch(:marker, nil)
      prefix = options.fetch(:prefix, nil)
      limit = [max, MAX_ITEMS_PER_LIST].min
      log "retrieving up to #{limit} of #{max} items from #{bucket_path}"
      query_string = "limit=#{limit}"
      query_string += "&marker=#{marker}" if marker
      query_string += "&prefix=#{prefix}" if prefix
      request = Net::HTTP::Get.new(bucket_path + "?#{query_string}")
      result = storage_request(request).body || ""
      result.split("\n").tap {|items|
        if max <= limit
          log "Got #{items.length} items; we don't need any more."
        elsif items.length < limit
          log "Got #{items.length} items; there can't be any more."
        else
          log "Got #{items.length} items; requesting #{max - limit} more."
          items.concat list(max: max - limit, marker: items.last, prefix: prefix)
        end
      }
    end

    def search(prefix)
      log "retrieving bucket listing from #{bucket_path} items starting with #{prefix}"
      list(prefix: prefix)
    end

    def metadata
      log "retrieving bucket metadata from #{bucket_path}"
      response = storage_request(Net::HTTP::Head.new(bucket_path))
      {
        :objects => response["X-Container-Object-Count"].to_i,
        :bytes => response["X-Container-Bytes-Used"].to_i
      }
    end

    def cdn_metadata
      log "retrieving bucket CDN metadata from #{bucket_path}"
      response = cdn_request(Net::HTTP::Head.new(bucket_path))
      {
        :cdn_enabled => response["X-CDN-Enabled"] == "True",
        :host => response["X-CDN-URI"],
        :ssl_host => response["X-CDN-SSL-URI"],
        :streaming_host => response["X-CDN-STREAMING-URI"],
        :ttl => response["X-TTL"].to_i,
        :log_retention => response["X-Log-Retention"] == "True"
      }
    end

    # use this with caution, it will make EVERY object in the bucket publicly available
    # via the CDN. CDN enabling can be done via the web UI but only with a TTL of 72 hours.
    # Using the API it's possible to set a TTL of 50 years.
    #
    def cdn_enable(ttl = 72.hours.to_i)
      log "enabling CDN access to #{bucket_path} with a cache expiry of #{ttl / 60} minutes"

      cdn_request Net::HTTP::Put.new(bucket_path, "X-TTL" => ttl.to_i.to_s)
    end

    # Generate a expiring URL for a file that is otherwise private. useful for providing temporary
    # access to files.
    #
    def expiring_url(object_key, temp_url_key, expires_at = Time.now.to_i + 60)
      digest = OpenSSL::Digest::Digest.new('sha1')

      method  = 'GET'
      expires = expires_at.to_i
      path    = File.join(bucket_path, object_key)
      data    = "#{method}\n#{expires}\n#{path}"

      hmac    = OpenSSL::HMAC.new(temp_url_key, digest)
      hmac << data

      "https://#{@account.storage_host}#{path}?temp_url_sig=#{hmac.hexdigest}&temp_url_expires=#{expires}"
    end

    private

    def upload_io(key, io, byte_count)
      if byte_count <= LARGE_FILE_THRESHOLD
        upload_io_standard(key, io, byte_count)
      else
        upload_io_large(key, io, byte_count)
      end
    end

    def upload_io_standard(key, io, byte_count)
      full_path = File.join(bucket_path, key)

      headers = {}
      headers['Content-Type']     = extension_content_type(full_path)
      if io.respond_to?(:path)
        headers['Content-Type'] ||= extension_content_type(io.path)
        headers['Content-Type'] ||= file_content_type(io.path)
        headers['Etag']           = md5(io.path)
      end
      headers['Content-Type']   ||= "application/octet-stream"
      if content_type_needs_cors(key)
        headers['Access-Control-Allow-Origin'] = "*"
      end

      log "uploading #{byte_count} bytes to #{full_path}"

      request = Net::HTTP::Put.new(full_path, headers)
      request.body_stream = io
      request.content_length = byte_count
      storage_request(request)
    end

    def upload_io_large(key, io, byte_count)
      segment_count = (byte_count.to_f / LARGE_FILE_SEGMENT_SIZE).ceil
      segments = []
      while segments.size < segment_count
        start_pos = 0 + (LARGE_FILE_SEGMENT_SIZE * segments.size)
        segment_key = "%s.%03d" % [key, segments.size]
        io.seek(start_pos)
        segment_io = StringIO.new(io.read(LARGE_FILE_SEGMENT_SIZE))
        result = upload_io_standard(segment_key, segment_io, segment_io.size)
        segments << {path: "#{@bucket_name}/#{segment_key}", etag: result["ETag"], size_bytes: segment_io.size}
      end
      manifest_key = "#{key}?multipart-manifest=put"
      manifest_body = StringIO.new(JSON.dump(segments))
      upload_io_standard(manifest_key, manifest_body, manifest_body.size)
    end

    def cdn_request(request, &block)
      cloud_request(request, @account.cdn_host, &block)
    end

    def storage_request(request, &block)
      cloud_request(request, @account.storage_host, &block)
    end

    def cloud_request(request, hostname, retries = 0, &block)
      cloud_http(hostname) do |http|
        request['X-Auth-Token'] = @account.auth_token
        http.request(request, &block)
      end
    rescue Timeout::Error
      if retries >= 3
        raise "Timeout from Rackspace at #{Time.now} while trying #{request.class} to #{request.path}"
      end

      unless defined?(Rails) && Rails.env.test?
        retry_interval = 5 + (retries.to_i * 5) # Retry after 5, 10, 15 and 20 seconds
        log "Rackspace timed out: retrying after #{retry_interval}s"
        sleep(retry_interval)
      end

      cloud_request(request, hostname, retries + 1, &block)
    end

    def cloud_http(hostname, &block)
      Net::HTTP.new(hostname, 443).tap {|http|
        http.use_ssl = true
        http.read_timeout = 70
      }.start do |http|
        response = block.call http
        if response.is_a?(Net::HTTPUnauthorized)
          log "Rackspace returned HTTP 401; refreshing auth before retrying."
          @account.refresh_cache
          response = block.call http
        end
        raise "Failure: Rackspace returned #{response.inspect}" unless response.is_a?(Net::HTTPSuccess)
        response
      end
    end

    def log(msg)
      if @logger.respond_to?(:debug)
        @logger.debug msg
      end
    end

    def bucket_path
      @bucket_path ||= File.join(@account.path, bucket_name)
    end

    def file_content_type(path)
      `file -b --mime-type \"#{path.gsub('"', '\"')}\"`.chomp
    end

    def extension_content_type(path)
      {
        ".css" => "text/css",
        ".eot" => "application/vnd.ms-fontobject",
        ".html" => "text/html",
        ".js" => "application/javascript",
        ".png" => "image/png",
        ".jpg" => "image/jpeg",
        ".txt" => "text/plain",
        ".woff" => "font/woff",
        ".zip" => "application/zip"
      }[File.extname(path)]
    end

    # Fonts need to be served with CORS headers to work in IE and FF
    #
    def content_type_needs_cors(path)
      [".eot",".ttf",".woff"].include?(File.extname(path))
    end

    def md5(path)
      digest = Digest::MD5.new
      File.open(path, 'rb') do |f|
        # read in 128K chunks
        f.each(1024 * 128) do |chunk|
          digest << chunk
        end
      end
      digest.hexdigest
    end
  end
end
