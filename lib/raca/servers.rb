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

      response = servers_client.post(servers_path, JSON.dump(request), json_headers)
      data = JSON.parse(response.body)['server']
      Raca::Server.new(@account, @region, data['id'])
    end

    def inspect
      "#<Raca::Servers:#{__id__} region=#{@region}>"
    end

    private

    def json_headers
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    end

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
      json = servers_client.get(servers_path, json_headers).body
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
        data = servers_client.get(flavors_path, json_headers).body
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
        data = servers_client.get(images_path, json_headers).body
        JSON.parse(data)['images']
      end
    end

    def image_names
      images.map {|row| row['name'] }
    end

    def image_name_to_id(str)
      str = str.to_s.downcase
      image = images.detect { |row|
        row['name'].downcase == str
      } || images.detect { |row|
        row['name'].downcase.include?(str)
      }
      if image
        image['id']
      else
        raise ArgumentError, "valid images are: #{image_names.join(', ')}"
      end
    end

    def servers_client
      @servers_client ||= @account.http_client(servers_host)
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
