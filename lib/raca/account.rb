require 'yaml'
require 'json'

module Raca

  # The rackspace auth API accepts a username and API key and returns a range
  # of settings that are used for interacting with their other APIS. Think
  # auth tokens, hostnames, paths, etc.
  #
  # This class caches these settings so we don't have to continually use our
  # username/key to retrieve them.
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

    def auth_token
      extract_value(cloudfiles_data, "access", "token", "id")
    end

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
    def service_names
      catalog = extract_value(cloudfiles_data, "access", "serviceCatalog") || {}
      catalog.map { |service|
        service["name"]
      }
    end

    def containers(region)
      Raca::Containers.new(self, region)
    end

    def servers(region)
      Raca::Servers.new(self, region)
    end

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
        if response.is_a? Net::HTTPSuccess
          cache_write(cache_key, JSON.load(response.body))
        end
      }
    end

    private

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
      catalog = extract_value(cloudfiles_data, "access", "serviceCatalog") || {}
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

    def cloudfiles_data
      refresh_cache unless cache_read(cache_key)

      cache_read(cache_key) || {}
    end

    def cache_key
      "raca-#{@username}"
    end

  end
end
