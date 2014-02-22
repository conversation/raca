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
      cloudfiles_data[:auth_token]
    end

    def storage_host
      URI.parse(cloudfiles_data[:storage_url]).host
    end

    def cdn_host
      URI.parse(cloudfiles_data[:cdn_url]).host
    end

    def path
      URI.parse(cloudfiles_data[:storage_url]).path
    end

    def server_host
      URI.parse(cloudfiles_data[:server_url]).host
    end

    def server_path
      URI.parse(cloudfiles_data[:server_url]).path
    end

    def ngserver_host
      URI.parse(cloudfiles_data[:ngserver_url]).host
    end

    def ngserver_path
      URI.parse(cloudfiles_data[:ngserver_url]).path
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
          json_data = JSON.load(response.body)
          cache_write(cache_key, {
            auth_token: extract_value(json_data, "access", "token", "id"),
            storage_url: ord_cloudfiles_url(json_data),
            server_url: cloudserver_url(json_data),
            ngserver_url: ngcloudserver_url(json_data),
            cdn_url: ord_cloudcdn_url(json_data)
          })
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

    # The API URL we should use to control cloud files in ORD
    #
    def ord_cloudfiles_url(data)
      endpoints = cloudfiles_catalog(data)["endpoints"] || []
      ord = endpoints.detect { |e| e["region"] == "ORD" } || {}
      ord["publicURL"]
    end

    # An array of all cloudfiles regions
    #
    def cloudfiles_catalog(data)
      catalog = extract_value(data, "access", "serviceCatalog") || {}
      catalog.detect { |s| s["name"] == "cloudFiles" } || {}
    end

    # The API URL we should use to control cloud files CDN in ORD
    #
    def ord_cloudcdn_url(data)
      endpoints = cloudcdn_catalog(data)["endpoints"] || []
      ord = endpoints.detect { |e| e["region"] == "ORD" } || {}
      ord["publicURL"]
    end

    # An array of all cloudfiles CDN regions
    #
    def cloudcdn_catalog(data)
      catalog = extract_value(data, "access", "serviceCatalog") || {}
      catalog.detect { |s| s["name"] == "cloudFilesCDN" } || {}
    end

    # The API URL we should use to control original cloud servers. They're all
    # in ORD so we don't get a choice.
    #
    def cloudserver_url(data)
      endpoints = cloudserver_catalog(data)["endpoints"] || []
      endpoint = endpoints.first || {}
      endpoint["publicURL"]
    end

    # An array of all 1st gen cloud server regions
    #
    def cloudserver_catalog(data)
      catalog = extract_value(data, "access", "serviceCatalog") || {}
      catalog.detect { |s| s["name"] == "cloudServers" } || {}
    end

    # The API URL we should use to control next gen cloud servers.
    #
    def ngcloudserver_url(data)
      endpoints = ngcloudserver_catalog(data)["endpoints"] || []
      ord = endpoints.detect { |e| e["region"] == "ORD" } || {}
      ord["publicURL"]
    end

    # An array of all next gen cloud server regions
    #
    def ngcloudserver_catalog(data)
      catalog = extract_value(data, "access", "serviceCatalog") || {}
      catalog.detect { |s| s["name"] == "cloudServersOpenStack" } || {}
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

    def app_config
      filename = File.dirname(__FILE__) + "/../../config/application.yml"
      @app_config ||= YAML.load_file(filename)
    end

    def cloudfiles_data
      refresh_cache unless cache_read(cache_key)

      cache_read(cache_key) || {}
    end

    def cache_key
      @cache_key ||= "raca-#{@username}"
    end

  end
end
