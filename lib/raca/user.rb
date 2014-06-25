module Raca
  # Represents a single user within the current account.
  #
  # You probably don't want to instantiate this directly,
  # see Raca::Account#users
  #
  class User
    attr_reader :username

    def initialize(account, username, opts = {})
      @account, @username = account, username
      @identity_url = @account.public_endpoint("identity")
      @logger = opts[:logger]
      @logger ||= Rails.logger if defined?(Rails)
    end

    def details
      response = identity_client.get(user_path)
      JSON.load(response.body)["user"]
    end

    def inspect
      "#<Raca::User:#{__id__} @username=#{@username}>"
    end

    private

    def identity_host
      URI.parse(@identity_url).host
    end

    def identity_path
      URI.parse(@identity_url).path
    end

    def user_path
      @user_path ||= File.join(identity_path, "users") + "?name=" + Raca::Util.url_encode(@username)
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
