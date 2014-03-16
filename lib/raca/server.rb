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

    attr_reader :server_name, :server_id

    def initialize(account, region, server_name)
      @account = account
      @region = region
      @servers_url = @account.public_endpoint("cloudServersOpenStack", region)
      @server_name = server_name
      @server_id = find_server_id(server_name)
    end

    # return true if this server exists on Rackspace
    #
    def exists?
      @server_id != nil
    end

    # create this server on Rackspace.
    #
    # flavor_name is a string that describes the amount of RAM. If you enter
    # an invalid option a list of valid options will be raised.
    #
    # image_name is a string that describes the OS image to use. If you enter
    # an invalid option a list of valid options will be raised. I suggest
    # starting with 'Ubuntu 10.04 LTS'
    #
    # files is an optional Hash of path to blobs. Use it to place a file on the
    # disk of the new server.
    #
    # Use it like this:
    #
    #     server.create(512, "Ubuntu 10.04 LTS", "/root/.ssh/authorised_keys" => File.read("/foo"))
    #
    def create(flavor_name, image_name, files = {})
      raise ArgumentError, "server already exists" if exists?

      request = {
        "server" => {
          "name" => @server_name,
          "imageRef" => image_name_to_id(image_name),
          "flavorRef" => flavor_name_to_id(flavor_name),
        }
      }
      files.each do |path, blob|
        request['server']['personality'] ||= []
        request['server']['personality'] << {
          'path' => path,
          'contents' => Base64.encode64(blob)
        }
      end

      data = cloud_request(Net::HTTP::Post.new(servers_path), JSON.dump(request)).body
      data = JSON.parse(data)['server']
      @server_id = data['id']
    end

    def delete!
      raise ArgumentError, "server doesn't exist" unless exists?

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
      raise ArgumentError, "server doesn't exist" unless exists?

      data = cloud_request(Net::HTTP::Get.new(server_path)).body
      JSON.parse(data)['server']
    end

    private

    def list
      json = cloud_request(Net::HTTP::Get.new(servers_path)).body
      JSON.parse(json)['servers']
    end

    def find_server_id(server_name)
      server = list.detect {|row|
        row["name"] == server_name
      }
      server ? server["id"] : nil
    end

    def flavors_path
      @flavors_path ||= File.join(account_path, "flavors")
    end

    def images_path
      @images_path ||= File.join(account_path, "images")
    end

    def server_path
      @server_path ||= File.join(account_path, "servers", @server_id.to_s)
    end

    def servers_path
      @servers_path ||= File.join(account_path, "servers")
    end

    def servers_host
      @servers_host ||= URI.parse(@servers_url).host
    end

    def account_path
      @account_path ||= URI.parse(@servers_url).path
    end

    def flavors
      @flavors ||= begin
        data = cloud_request(Net::HTTP::Get.new(flavors_path)).body
        JSON.parse(data)['flavors']
      end
    end

    def flavor_names
      flavors.map {|row| row['name'] }
    end

    def flavor_name_to_id(str)
      flavor = flavors.detect {|row|
        row['name'].downcase.include?(str.to_s.downcase)
      }
      if flavor
        flavor['id']
      else
        raise ArgumentError, "valid flavors are: #{flavor_names.join(', ')}"
      end
    end

    def images
      @images ||= begin
        data = cloud_request(Net::HTTP::Get.new(images_path)).body
        JSON.parse(data)['images']
      end
    end

    def image_names
      images.map {|row| row['name'] }
    end

    def image_name_to_id(str)
      image = images.detect {|row|
        row['name'].downcase.include?(str.to_s.downcase)
      }
      if image
        image['id']
      else
        raise ArgumentError, "valid images are: #{image_names.join(', ')}"
      end
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
        raise "Failure: Rackspace returned #{response.inspect}" unless response.is_a?(Net::HTTPSuccess)
        response
      end
    rescue Timeout::Error => e
      raise e if retries <= 0

      cloud_http(hostname, retries - 1, &block)
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
