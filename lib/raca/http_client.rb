require 'net/http'
require 'openssl'

module Raca

  # A thin wrapper around Net::HTTP. It's aware of some common details of
  # the rackspace APIs and has an API to match.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#http_client
  #
  class HttpClient

    def initialize(account, hostname, opts = {})
      @account, @hostname = account, hostname.to_s
      raise ArgumentError, "hostname must be plain hostname, leave the protocol out" if @hostname[/\Ahttp/]
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    def get(path, headers = {}, &block)
      cloud_request(Net::HTTP::Get.new(path, headers), &block)
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      cloud_request(Net::HTTP::Get.new(path, headers), &block)
    end

    def head(path, headers = {})
      cloud_request(Net::HTTP::Head.new(path, headers))
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      cloud_request(Net::HTTP::Head.new(path, headers))
    end

    def delete(path, headers = {})
      cloud_request(Net::HTTP::Delete.new(path, headers))
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      cloud_request(Net::HTTP::Delete.new(path, headers))
    end

    def put(path, headers = {})
      cloud_request(Net::HTTP::Put.new(path, headers))
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      cloud_request(Net::HTTP::Put.new(path, headers))
    end

    def streaming_put(path, io, byte_count, headers = {})
      cloud_request(build_streaming_put_request(path, io, byte_count, headers))
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      io.rewind if io.respond_to?(:rewind)
      cloud_request(build_streaming_put_request(path, io, byte_count, headers))
    end

    def post(path, body, headers = {})
      request = Net::HTTP::Post.new(path, headers)
      request.body = body if body
      cloud_request(request)
    rescue Raca::UnauthorizedError
      @account.refresh_cache
      request = Net::HTTP::Post.new(path, headers)
      request.body = body if body
      cloud_request(request)
    end

    private

    def build_streaming_put_request(path, io, byte_count, headers)
      request = Net::HTTP::Put.new(path, headers)
      request.body_stream = io
      request.content_length = byte_count
      request
    end

    # perform an HTTP request to rackpsace.
    #
    # request is a Net::HTTP request object.
    # This can be called with and without a block. Without a block, the response
    # is returned as you'd expect
    #
    #     response = http_client.cloud_request(request)
    #
    # With the block form, the response is yielded to the block:
    #
    #     http_client.cloud_request(request) do |response|
    #       puts response
    #     end
    #
    def cloud_request(request, &block)
      cloud_http do |http|
        request['X-Auth-Token'] = @account.auth_token
        request['User-Agent'] = "raca 0.3.3 (http://rubygems.org/gems/raca)"
        http.request(request, &block)
      end
    end

    def cloud_http(&block)
      Net::HTTP.start(@hostname, 443, use_ssl: true, read_timeout: 70) do |http|
        response = block.call(http)
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
      when 401 then UnauthorizedError
      when 404 then NotFoundError
      when 500 then ServerError
      else
        HTTPError
      end
      raise error_klass, "Rackspace returned HTTP status #{response.code} (rackspace transaction id: #{response["X-TRANS-ID"]})"
    end

    def log(msg)
      if @logger.respond_to?(:debug)
        @logger.debug msg
      end
    end

  end
end

