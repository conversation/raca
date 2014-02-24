module Raca
  class Servers
    def initialize(account, region)
      @account, @region = account, region
    end

    def get(server_name)
      Raca::Server.new(@account, @region, server_name)
    end
  end
end
