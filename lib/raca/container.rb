require 'net/http'
require 'digest/md5'
require 'openssl'
require 'uri'

module Raca

  # Represents a single cloud files container. Contains methods for uploading,
  # downloading, collecting stats, listing files, etc.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#containers
  #
  class Container
    MAX_ITEMS_PER_LIST = 10_000
    LARGE_FILE_THRESHOLD = 5_368_709_120 # 5 Gb
    LARGE_FILE_SEGMENT_SIZE = 104_857_600 # 100 Mb
    RETRY_PAUSE = 5

    attr_reader :container_name

    def initialize(account, region, container_name, opts = {})
      raise ArgumentError, "The container name must not contain '/'." if container_name['/']
      @account, @region, @container_name = account, region, container_name
      @storage_url = @account.public_endpoint("cloudFiles", region)
      @cdn_url     = @account.public_endpoint("cloudFilesCDN", region)
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    # Upload data_or_path (which may be a filename or an IO) to the container, as key.
    #
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
    #
    def delete(key)
      log "deleting #{key} from #{container_path}"
      response = storage_request(Net::HTTP::Delete.new(File.join(container_path, key)))
      (200..299).cover?(response.code.to_i)
    end

    # Remove +key+ from the CDN edge nodes on which it is currently cached. The object is
    # not deleted from the container: as the URL is re-requested, the edge cache will be
    # re-filled with the object currently in the container.
    #
    # This shouldn't be used except when it's really required (e.g. when a piece has to be
    # taken down) because it's expensive: it lodges a support ticket at Akamai. (!)
    #
    def purge_from_akamai(key, email_address)
      log "Requesting #{File.join(container_path, key)} to be purged from the CDN"
      response = cdn_request(Net::HTTP::Delete.new(
        File.join(container_path, key),
        'X-Purge-Email' => email_address
      ))
      (200..299).cover?(response.code.to_i)
    end

    # Returns some metadata about a single object in this container.
    #
    def object_metadata(key)
      object_path = File.join(container_path, key)
      log "Requesting metadata from #{object_path}"

      response = storage_request(Net::HTTP::Head.new(object_path))
      {
        :content_type => response["Content-Type"],
        :bytes => response["Content-Length"].to_i
      }
    end

    # Download the object at key into a local file at filepath.
    #
    # Returns the number of downloaded bytes.
    #
    def download(key, filepath)
      log "downloading #{key} from #{container_path}"
      response = storage_request(Net::HTTP::Get.new(File.join(container_path, key))) do |response|
        File.open(filepath, 'wb') do |io|
          response.read_body do |chunk|
            io.write(chunk)
          end
        end
      end
      response["Content-Length"].to_i
    end

    # Return an array of files in the container.
    #
    # Supported options
    #
    # max - the maximum number of items to return
    # marker - return items alphabetically after this key. Useful for pagination
    # prefix - only return items that start with this string
    #
    def list(options = {})
      max = options.fetch(:max, MAX_ITEMS_PER_LIST)
      marker = options.fetch(:marker, nil)
      prefix = options.fetch(:prefix, nil)
      limit = [max, MAX_ITEMS_PER_LIST].min
      log "retrieving up to #{limit} of #{max} items from #{container_path}"
      query_string = "limit=#{limit}"
      query_string += "&marker=#{marker}" if marker
      query_string += "&prefix=#{prefix}" if prefix
      request = Net::HTTP::Get.new(container_path + "?#{query_string}")
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

    # Returns an array of object keys that start with prefix. This is a convenience
    # method that is equivilant to:
    #
    #     container.list(prefix: "foo/bar/")
    #
    def search(prefix)
      log "retrieving container listing from #{container_path} items starting with #{prefix}"
      list(prefix: prefix)
    end

    # Return some basic stats on the current container.
    #
    def metadata
      log "retrieving container metadata from #{container_path}"
      response = storage_request(Net::HTTP::Head.new(container_path))
      {
        :objects => response["X-Container-Object-Count"].to_i,
        :bytes => response["X-Container-Bytes-Used"].to_i
      }
    end

    # Return the key details for CDN access to this container. Can be called
    # on non CDN enabled containers, but the details won't make much sense.
    #
    def cdn_metadata
      log "retrieving container CDN metadata from #{container_path}"
      response = cdn_request(Net::HTTP::Head.new(container_path))
      {
        :cdn_enabled => response["X-CDN-Enabled"] == "True",
        :host => response["X-CDN-URI"],
        :ssl_host => response["X-CDN-SSL-URI"],
        :streaming_host => response["X-CDN-STREAMING-URI"],
        :ttl => response["X-TTL"].to_i,
        :log_retention => response["X-Log-Retention"] == "True"
      }
    end

    # use this with caution, it will make EVERY object in the container publicly available
    # via the CDN. CDN enabling can be done via the web UI but only with a TTL of 72 hours.
    # Using the API it's possible to set a TTL of 50 years.
    #
    # TTL is defined in seconds, default is 72 hours.
    #
    def cdn_enable(ttl = 259200)
      log "enabling CDN access to #{container_path} with a cache expiry of #{ttl / 60} minutes"

      response = cdn_request(Net::HTTP::Put.new(container_path, "X-TTL" => ttl.to_i.to_s))
      (200..299).cover?(response.code.to_i)
    end

    # Generate a expiring URL for a file that is otherwise private. useful for providing temporary
    # access to files.
    #
    def expiring_url(object_key, temp_url_key, expires_at = Time.now.to_i + 60)
      digest = OpenSSL::Digest::Digest.new('sha1')

      method  = 'GET'
      expires = expires_at.to_i
      path    = File.join(container_path, object_key)
      data    = "#{method}\n#{expires}\n#{path}"

      hmac    = OpenSSL::HMAC.new(temp_url_key, digest)
      hmac << data

      "https://#{storage_host}#{path}?temp_url_sig=#{hmac.hexdigest}&temp_url_expires=#{expires}"
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
      full_path = File.join(container_path, key)

      headers = {}
      headers['Content-Type']     = extension_content_type(full_path)
      if io.respond_to?(:path)
        headers['Content-Type'] ||= extension_content_type(io.path)
        headers['Content-Type'] ||= file_content_type(io.path)
      end
        headers['Etag']           = md5_io(io)
      headers['Content-Type']   ||= "application/octet-stream"
      if content_type_needs_cors(key)
        headers['Access-Control-Allow-Origin'] = "*"
      end

      log "uploading #{byte_count} bytes to #{full_path}"

      request = Net::HTTP::Put.new(full_path, headers)
      request.body_stream = io
      request.content_length = byte_count
      response = storage_request(request)
      response['ETag']
    end

    def upload_io_large(key, io, byte_count)
      segment_count = (byte_count.to_f / LARGE_FILE_SEGMENT_SIZE).ceil
      segments = []
      while segments.size < segment_count
        start_pos = 0 + (LARGE_FILE_SEGMENT_SIZE * segments.size)
        segment_key = "%s.%03d" % [key, segments.size]
        io.seek(start_pos)
        segment_io = StringIO.new(io.read(LARGE_FILE_SEGMENT_SIZE))
        etag = upload_io_standard(segment_key, segment_io, segment_io.size)
        segments << {path: "#{@container_name}/#{segment_key}", etag: etag, size_bytes: segment_io.size}
      end
      manifest_key = "#{key}?multipart-manifest=put"
      manifest_body = StringIO.new(JSON.dump(segments))
      upload_io_standard(manifest_key, manifest_body, manifest_body.size)
    end

    def cdn_request(request, &block)
      cloud_request(request, cdn_host, &block)
    end

    def storage_request(request, &block)
      cloud_request(request, storage_host, &block)
    end

    def cloud_request(request, hostname, retries = 0, &block)
      cloud_http(hostname) do |http|
        request['X-Auth-Token'] = @account.auth_token
        http.request(request, &block)
      end
    rescue Timeout::Error
      if retries >= 3
        raise Raca::TimeoutError, "Timeout from Rackspace while trying #{request.class} to #{request.path}"
      end

      retry_interval = RETRY_PAUSE + (retries.to_i * RETRY_PAUSE) # Retry after 5, 10, 15 and 20 seconds
      log "Rackspace timed out: retrying after #{retry_interval}s"
      sleep(retry_interval)

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
        if response.is_a?(Net::HTTPSuccess)
          response
        else
          raise_on_error(response)
        end
      end
    end

    def raise_on_error(response)
      error_klass = case response.code.to_i
      when 400 then BadRequestError
      when 404 then NotFoundError
      when 500 then ServerError
      else
        HTTPError
      end
      raise error_klass, "Rackspace returned HTTP status #{response.code}"
    end

    def log(msg)
      if @logger.respond_to?(:debug)
        @logger.debug msg
      end
    end

    def storage_host
      URI.parse(@storage_url).host
    end

    def storage_path
      URI.parse(@storage_url).path
    end

    def cdn_host
      URI.parse(@cdn_url).host
    end

    def cdn_path
      URI.parse(@cdn_url).path
    end

    def container_path
      @container_path ||= File.join(storage_path, container_name)
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

    def md5_io(io)
      io.seek(0)
      digest = Digest::MD5.new
      # read in 128K chunks
      io.each(1024 * 128) do |chunk|
        digest << chunk
      end
      io.seek(0)
      digest.hexdigest
    end
  end
end
