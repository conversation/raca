module Raca
  # Represents a collection of users associated with a rackspace account
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#users
  #
  class Users
    def initialize(account, opts = {})
      @account = account
      @identity_url = @account.public_endpoint("identity")
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    def get(username)
      list.detect { |user| user.username == username }
    end

    def inspect
      "#<Raca::Users:#{__id__}>"
    end

    private

    # TODO should this (or something like it) be part of the public API?
    def list
      log "retrieving users list from #{users_path}"
      response = identity_client.get(users_path)
      records = JSON.load(response.body)["users"]
      records.map { |record|
        record["username"]
      }.map { |username|
        Raca::User.new(@account, username)
      }
    end

    def identity_host
      URI.parse(@identity_url).host
    end

    def identity_path
      URI.parse(@identity_url).path
    end

    def users_path
      File.join(identity_path, "users")
    end

    def identity_client
      @identity_client ||= @account.http_client(identity_host)
    end

    def log(msg)
      if @logger.respond_to?(:debug)
        @logger.debug msg
      end
    end
  end
end
