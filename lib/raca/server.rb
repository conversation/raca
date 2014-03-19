require 'json'
require 'base64'
require 'net/http'

module Raca
  # Represents a single cloud server. Contains methods for deleting a server,
  # listing IP addresses, checking the state, etc.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#servers
  #
  class Server

    attr_reader :server_id

    def initialize(account, region, server_id)
      @account = account
      @region = region
      @servers_url = @account.public_endpoint("cloudServersOpenStack", region)
      @server_id = server_id
    end

    def delete!
      response = cloud_request(Net::HTTP::Delete.new(server_path))
      response.is_a? Net::HTTPSuccess
    end

    # Poll Rackspace and return once a server is in an active state. Useful after
    # creating a new server
    #
    def wait_for_active
      until details['status'] == 'ACTIVE'
        log "Not online yet. Waiting..."
        sleep 10
      end
    end

    # An array of private IP addresses for the server. They can be ipv4 or ipv6
    #
    def private_addresses
      details['addresses']['private'].map { |i| i["addr"] }
    end

    # An array of public IP addresses for the server. They can be ipv4 or ipv6
    #
    def public_addresses
      details['addresses']['public'].map { |i| i["addr"] }
    end

    # A Hash of various matadata about the server
    #
    def details
      data = cloud_request(Net::HTTP::Get.new(server_path)).body
      JSON.parse(data)['server']
    end

    private

    def servers_host
      @servers_host ||= URI.parse(@servers_url).host
    end

    def account_path
      @account_path ||= URI.parse(@servers_url).path
    end

    def server_path
      @server_path ||= File.join(account_path, "servers", @server_id.to_s)
    end

    def cloud_request(request, body = nil)
      request['X-Auth-Token'] = @account.auth_token
      request['Content-Type'] = 'application/json'
      request['Accept']       = 'application/json'
      cloud_http(servers_host) do |http|
        http.request(request, body)
      end
    end

    def cloud_http(hostname, retries = 3, &block)
      http = Net::HTTP.new(hostname, 443)
      http.use_ssl = true
      http.start do |http|
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
        response
      end
    rescue Timeout::Error
      if retries <= 0
        raise Raca::TimeoutError, "Timeout from Rackspace while trying #{request.class} to #{request.path}"
      end

      cloud_http(hostname, retries - 1, &block)
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
      if defined?(Rails)
        Rails.logger.info msg
      else
        puts msg
      end
    end

  end
end
