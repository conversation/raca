module Raca
  # Represents a collection of cloud files containers within a single region.
  #
  # There's a handful of methods that relate to the entire collection, but this
  # is primarily used to retrieve a single Raca::Container object.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#containers
  #
  class Containers
    def initialize(account, region, opts = {})
      @account, @region = account, region
      @storage_url = @account.public_endpoint("cloudFiles", region)
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    def get(container_name)
      Raca::Container.new(@account, @region, container_name)
    end

    # Return metadata on all containers
    #
    def metadata
      log "retrieving containers metadata from #{storage_path}"
      response    = storage_request(Net::HTTP::Head.new(storage_path))
      {
        :containers => response["X-Account-Container-Count"].to_i,
        :objects    => response["X-Account-Object-Count"].to_i,
        :bytes      => response["X-Account-Bytes-Used"].to_i
      }
    end

    # Set the secret key that will be used to generate expiring URLs for all cloud
    # files containers on the current account. This value should be passed to the
    # expiring_url() method.
    #
    # Use this with caution, this will invalidate all previously generated expiring
    # URLS *FOR THE ENTIRE ACCOUNT*
    #
    def set_temp_url_key(secret)
      log "setting Account Temp URL Key on #{storage_path}"

      request = Net::HTTP::Post.new(storage_path, "X-Account-Meta-Temp-Url-Key" => secret.to_s)
      response = storage_request(request)
      (200..299).cover?(response.code.to_i)
    end

    private

    def storage_host
      URI.parse(@storage_url).host
    end

    def storage_path
      URI.parse(@storage_url).path
    end

    def storage_request(request, &block)
      cloud_request(request, storage_host, &block)
    end

    def cloud_request(request, hostname, &block)
      cloud_http(hostname) do |http|
        request['X-Auth-Token'] = @account.auth_token
        http.request(request, &block)
      end
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
  end
end
