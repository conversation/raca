module Raca
  # Represents a collection of cloud servers within a single region.
  #
  # There's currently no methods that relate to the entire collection,
  # this is primarily used to retrieve a single Raca::Server object.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#servers
  #
  class Servers
    def initialize(account, region)
      @account, @region = account, region
      @servers_url = @account.public_endpoint("cloudServersOpenStack", region)
    end

    def get(server_name)
      server_id = find_server_id(server_name)
      if server_id
        Raca::Server.new(@account, @region, server_id)
      else
        nil
      end
    end

    # create a new server on Rackspace.
    #
    # server_name is a free text name you want to assign the server.
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
    #     server.create("my-server", 512, "Ubuntu 10.04 LTS", "/root/.ssh/authorised_keys" => File.read("/foo"))
    #
    def create(server_name, flavor_name, image_name, files = {})
      request = {
        "server" => {
          "name" => server_name,
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
      Raca::Server.new(@account, @region, data['id'])
    end

    private

    def servers_host
      @servers_host ||= URI.parse(@servers_url).host
    end

    def account_path
      @account_path ||= URI.parse(@servers_url).path
    end

    def flavors_path
      @flavors_path ||= File.join(account_path, "flavors")
    end

    def images_path
      @images_path ||= File.join(account_path, "images")
    end

    def servers_path
      @servers_path ||= File.join(account_path, "servers")
    end

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
