require 'spec_helper'
require 'webmock/rspec'

describe Raca::Server do
  let!(:account) {
    info = double(Raca::Account)
    allow(info).to receive(:public_endpoint).with("cloudServersOpenStack", :ord).and_return("https://the-cloud.com/account")
    allow(info).to receive(:auth_token).and_return('token')
    allow(info).to receive(:refresh_cache).and_return(true)
    info
  }
  let!(:http_client) { Raca::HttpClient.new(account, "the-cloud.com") }

  describe '#initialization' do

    context "with an existing server" do
      let!(:server) {
        Raca::Server.new(account, :ord, "123")
      }

      it 'should set the server_id atttribute' do
        expect(server.server_id).to eq("123")
      end
    end

  end

  describe '#details' do
    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)

      expect(http_client).to receive(:get).with(
        "/account/servers/123", 'Accept'=>'application/json', 'Content-Type'=>'application/json'
      ).and_return(
        double("Net::HTTPSuccess",
                body: JSON.dump(
                {server:
                 {progress:100,
                  id:123,
                  imageId:112,
                  flavorId:2,
                  status:"ACTIVE",
                  name:"server1",
                  hostId:"a42e65b66e4d7fa76c0ccdd01de25cb3",
                  addresses: {
                    public:["50.56.202.20"],
                    private:["10.178.237.99"]
                  },
                  metadata:{}}
                }
              )
          )
      )
    end

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "123") }

      it 'should return a hash of interesting data' do
        server.details.tap { |result|
          expect(result).to be_a(Hash)
          expect(result["status"]).to eq("ACTIVE")
        }
      end
    end
  end

  describe '#delete!' do

    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)

      expect(http_client).to receive(:delete).with(
        "/account/servers/123", 'Accept'=>'application/json', 'Content-Type'=>'application/json'
      ).and_return(
        Net::HTTPNoContent.new("1.1", "204", "OK")
      )
    end

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "123") }

      it 'should return true' do
        expect(server.delete!).to eq true
      end
    end

  end
end
