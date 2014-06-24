require 'json'
require 'base64'

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
      response = servers_client.delete(server_path, json_headers)
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
      data = servers_client.get(server_path, json_headers).body
      JSON.parse(data)['server']
    end

    def inspect
      "#<Raca::Server:#{__id__} region=#{@region} server_id=#{@server_id}>"
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

    def server_path
      @server_path ||= File.join(account_path, "servers", @server_id.to_s)
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
