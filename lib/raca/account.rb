require 'yaml'
require 'json'

module Raca

  # This is your entrypoint to the rackspace API. Start by creating a
  # Raca::Account object and then use the instance method to access each of
  # the supported rackspace APIs.
  #
  class Account

    def initialize(username, key, cache = nil)
      @username, @key, @cache = username, key, cache
      @cache ||= if defined?(Rails)
        Rails.cache
      else
        {}
      end
    end

    # Return the temporary token that should be used when making further API
    # requests.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.auth_token
    #
    def auth_token
      extract_value(identity_data, "access", "token", "id")
    end

    # Return the public API URL for a particular rackspace service.
    #
    # Use Account#service_names to see a list of valid service_name's for this.
    #
    # Check the project README for an updated list of the available regions.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.public_endpoint("cloudServers", :syd)
    #
    def public_endpoint(service_name, region)
      region = region.to_s.upcase
      endpoints = service_endpoints(service_name)
      regional_endpoint = endpoints.detect { |e| e["region"] == region } || {}
      regional_endpoint["publicURL"]
    end

    # Return the names of the available services. As rackspace add new services and
    # APIs they should appear here.
    #
    # Any name returned from here can be passe to #public_endpoint to get the API
    # endpoint for that service
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.service_names
    #
    def service_names
      catalog = extract_value(identity_data, "access", "serviceCatalog") || {}
      catalog.map { |service|
        service["name"]
      }
    end

    # Return a Raca::Containers object for a region. Use this to interact with the
    # cloud files service.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.containers(:ord)
    #
    def containers(region)
      Raca::Containers.new(self, region)
    end

    # Return a Raca::Containers object for a region. Use this to interact with the
    # next gen cloud servers service.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.servers(:ord)
    #
    def servers(region)
      Raca::Servers.new(self, region)
    end

    # Raca classes use this method to occasionally re-authenticate with the rackspace
    # servers. You can probable ignore it.
    #
    def refresh_cache
      Net::HTTP.new('identity.api.rackspacecloud.com', 443).tap {|http|
        http.use_ssl = true
      }.start {|http|
        payload = {
          auth: {
            'RAX-KSKEY:apiKeyCredentials' => {
              username: @username,
              apiKey: @key
            }
          }
        }
        response = http.post(
          '/v2.0/tokens',
          JSON.dump(payload),
          {'Content-Type' => 'application/json'},
        )
        if response.is_a?(Net::HTTPSuccess)
          cache_write(cache_key, JSON.load(response.body))
        else
          raise_on_error(response)
        end
      }
    end

    # Return a Raca::HttpClient suitable for making requests to hostname.
    #
    def http_client(hostname)
      Raca::HttpClient.new(self, hostname)
    end

    private

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

    # This method is opaque, but it was the best I could come up with using just
    # the standard library. Sorry.
    #
    # Use this to safely extract values from nested hashes:
    #
    #     data = {a: {b: {c: 1}}}
    #     extract_value(data, :a, :b, :c)
    #     => 1
    #
    #     extract_value(data, :a, :b, :d)
    #     => nil
    #
    #     extract_value(data, :d)
    #     => nil
    #
    def extract_value(data, *keys)
      if keys.empty?
        data
      elsif data.respond_to?(:[]) && data[keys.first]
        extract_value(data[keys.first], *keys.slice(1,100))
      else
        nil
      end
    end

    # An array of all the endpoints for a particular service (like cloud files,
    # cloud servers, dns, etc)
    #
    def service_endpoints(service_name)
      catalog = extract_value(identity_data, "access", "serviceCatalog") || {}
      service = catalog.detect { |s| s["name"] == service_name } || {}
      service["endpoints"] || []
    end

    def cache_read(key)
      if @cache.respond_to?(:read) # rails cache
        @cache.read(key)
      else
        @cache[key]
      end
    end

    def cache_write(key, value)
      if @cache.respond_to?(:write) # rails cache
        @cache.write(key, value)
      else
        @cache[key] = value
      end
    end

    def identity_data
      refresh_cache unless cache_read(cache_key)

      cache_read(cache_key) || {}
    end

    def cache_key
      "raca-#{@username}"
    end

  end
end
