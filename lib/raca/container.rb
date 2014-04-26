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
    # If headers are provided they will be added to to upload request. Use this to
    # manually specify content type, content disposition, CORS headers, etc.
    #
    def upload(key, data_or_path, headers = {})
      case data_or_path
      when StringIO, File
        upload_io(key, data_or_path, data_or_path.size, headers)
      when String
        File.open(data_or_path, "rb") do |io|
          upload_io(key, io, io.stat.size, headers)
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
      object_path = File.join(container_path, Raca::Util.url_encode(key))
      response = storage_client.delete(object_path)
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
      response = cdn_client.delete(
        File.join(container_path, Raca::Util.url_encode(key)),
        'X-Purge-Email' => email_address
      )
      (200..299).cover?(response.code.to_i)
    end

    # Returns some metadata about a single object in this container.
    #
    def object_metadata(key)
      object_path = File.join(container_path, Raca::Util.url_encode(key))
      log "Requesting metadata from #{object_path}"

      response = storage_client.head(object_path)
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
      object_path = File.join(container_path, Raca::Util.url_encode(key))
      response = storage_client.get(object_path) do |response|
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
    # details - return extra details for each file - size, md5, etc
    #
    def list(options = {})
      max = options.fetch(:max, 100_000_000)
      marker = options.fetch(:marker, nil)
      prefix = options.fetch(:prefix, nil)
      details = options.fetch(:details, nil)
      limit = [max, MAX_ITEMS_PER_LIST].min
      log "retrieving up to #{max} items from #{container_path}"
      request_path = list_request_path(marker, prefix, details, limit)
      result = storage_client.get(request_path).body || ""
      if details
        result = JSON.parse(result)
      else
        result = result.split("\n")
      end
      result.tap {|items|
        if max <= limit
          log "Got #{items.length} items; we don't need any more."
        elsif items.length < limit
          log "Got #{items.length} items; there can't be any more."
        else
          log "Got #{items.length} items; requesting #{limit} more."
          details ? marker = items.last["name"] : marker = items.last
          items.concat list(max: max-items.length, marker: marker, prefix: prefix, details: details)
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
      response = storage_client.head(container_path)
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
      response = cdn_client.head(container_path)
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

      response = cdn_client.put(container_path, "X-TTL" => ttl.to_i.to_s)
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
      encoded_path = File.join(container_path, Raca::Util.url_encode(object_key))
      data    = "#{method}\n#{expires}\n#{path}"

      hmac    = OpenSSL::HMAC.new(temp_url_key, digest)
      hmac << data

      "https://#{storage_host}#{encoded_path}?temp_url_sig=#{hmac.hexdigest}&temp_url_expires=#{expires}"
    end

    private

    # build the request path for listing the contents of a container
    #
    def list_request_path(marker, prefix, details, limit)
      query_string = "limit=#{limit}"
      query_string += "&marker=#{Raca::Util.url_encode(marker)}" if marker
      query_string += "&prefix=#{Raca::Util.url_encode(prefix)}" if prefix
      query_string += "&format=json"      if details
      container_path + "?#{query_string}"
    end


    def upload_io(key, io, byte_count, headers = {})
      if byte_count <= LARGE_FILE_THRESHOLD
        upload_io_standard(key, io, byte_count, headers)
      else
        upload_io_large(key, io, byte_count, headers)
      end
    end

    def upload_io_standard(key, io, byte_count, headers = {})
      full_path = File.join(container_path, Raca::Util.url_encode(key))

      headers['Content-Type']   ||= extension_content_type(full_path)
      if io.respond_to?(:path)
        headers['Content-Type'] ||= extension_content_type(io.path)
      end
      headers['ETag']           = md5_io(io)
      headers['Content-Type']   ||= "application/octet-stream"
      if content_type_needs_cors(key)
        headers['Access-Control-Allow-Origin'] = "*"
      end

      log "uploading #{byte_count} bytes to #{full_path}"
      put_upload(full_path, headers, byte_count, io)
    end

    def upload_io_large(key, io, byte_count, headers = {})
      segment_count = (byte_count.to_f / LARGE_FILE_SEGMENT_SIZE).ceil
      segments = []
      while segments.size < segment_count
        start_pos = 0 + (LARGE_FILE_SEGMENT_SIZE * segments.size)
        segment_key = "%s.%03d" % [key, segments.size]
        io.seek(start_pos)
        segment_io = StringIO.new(io.read(LARGE_FILE_SEGMENT_SIZE))
        etag = upload_io_standard(segment_key, segment_io, segment_io.size, headers)
        segments << {path: "#{@container_name}/#{segment_key}", etag: etag, size_bytes: segment_io.size}
      end
      full_path = File.join(container_path, Raca::Util.url_encode(key)) + "?multipart-manifest=put"
      manifest_body = StringIO.new(JSON.dump(segments))
      put_upload(full_path, {}, manifest_body.string.bytesize, manifest_body)
    end

    def put_upload(full_path, headers, byte_count, io)
      response = storage_client.streaming_put(full_path, io, byte_count, headers)
      response['ETag']
    end

    def cdn_client
      @cdn_client ||= @account.http_client(cdn_host)
    end

    def storage_client
      @storage_client ||= @account.http_client(storage_host)
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
      @container_path ||= File.join(storage_path, Raca::Util.url_encode(container_name))
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
