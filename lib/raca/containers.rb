module Raca
  class Containers
    def initialize(account, region)
      @account, @region = account, region
    end

    def get(container_name)
      Raca::Bucket.new(@account, @region, container_name)
    end
  end
end
