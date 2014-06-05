require 'spec_helper'

describe Raca::Containers do

  let!(:account) {
    info = double(Raca::Account)
    allow(info).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
    allow(info).to receive(:auth_token).and_return('token')
    allow(info).to receive(:refresh_cache).and_return(true)
    info
  }
  let!(:http_client) { Raca::HttpClient.new(account, "the-cloud.com") }
  let!(:logger) { double(Object).as_null_object }
  let!(:containers) { Raca::Containers.new(account, :ord) }

  describe '#get' do
    it 'should return a new Raca::Container' do
      expect(Raca::Container).to receive(:new).with(account, :ord, "container_name")
      containers.get("container_name")
    end
  end

  describe '#containers_metadata' do
    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:head).with("/account").and_return(
        Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
          response.add_field('X-Account-Container-Count', '5')
          response.add_field('X-Account-Object-Count', '10')
          response.add_field('X-Account-Bytes-Used', '1024')
        }
      )
    end

    it 'should log what it indends to do' do
      logger.should_receieve(:debug).with('retrieving containers metadata from /account/test')
      containers.metadata
    end

    it 'should return a hash of results' do
      expect(containers.metadata).to eq({
        containers: 5,
        objects: 10,
        bytes: 1024,
      })
    end
  end

  describe '#set_temp_url_key' do
    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:post).with("/account", nil, 'X-Account-Meta-Temp-Url-Key'=>'secret').and_return(
        Net::HTTPCreated.new("1.1", 200, "OK")
      )
    end

    it 'should log what it indends to do' do
      logger.should_receieve(:debug).with('setting Account Temp URL Key on /account/test')
      containers.set_temp_url_key("secret")
    end

    it 'should return true' do
      expect(containers.set_temp_url_key("secret")).to eq(true)
    end
  end

end
