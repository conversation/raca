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
    end

    def get(server_name)
      Raca::Server.new(@account, @region, server_name)
    end
  end
end
