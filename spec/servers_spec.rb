require 'spec_helper'
require 'webmock/rspec'

describe Raca::Servers do
  let!(:account) {
    info = double(Raca::Account)
    allow(info).to receive(:public_endpoint).with("cloudServersOpenStack", :ord).and_return("https://the-cloud.com/account")
    allow(info).to receive(:auth_token).and_return('token')
    allow(info).to receive(:refresh_cache).and_return(true)
    info
  }
  let!(:http_client) { Raca::HttpClient.new(account, "the-cloud.com") }

  before(:each) do
    allow(account).to receive(:http_client).and_return(http_client)
  end

  describe '#create' do

    context "with a new server" do
      let!(:flavours_response) {
        double("Net::HTTPSuccess", body: JSON.dump({flavors: [{id:1,name:"256 server"},{id:2,name:"512 server"}]}))
      }
      let!(:images_response) {
        double("Net::HTTPSuccess", body: JSON.dump({images:[{id:112,name:"Ubuntu 10.04 LTS"},{id:104,name:"Debian 6 (Squeeze)"}]}))
      }
      let!(:servers_response) {
        double("Net::HTTPSuccess",
               body: JSON.dump(
                 {server:
                   {progress:0,
                   id:456,
                   imageId:112,
                   flavorId:2,
                   status:"BUILD",
                   adminPass:"server20efH35xMP",
                   name:"server2",
                   hostId:"663c67e3f3f6b8b402e7d6be06d0a08e",
                   addresses:{
                     public:["108.171.178.15"],
                     private:["10.179.133.145"]
                   },
                   metadata:{}}
                }
             )
           )
      }

      let!(:servers) { Raca::Servers.new(account, :ord) }

      context "when passed an invalid flavor" do
        before do
          expect(http_client).to receive(:get).with(
            "/account/flavors", "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(flavours_response)
          expect(http_client).to receive(:get).with(
            "/account/images", "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(images_response)
        end

        it 'should raise an exception' do
          expect {
            servers.create("server1", 1024, "LTS")
          }.to raise_error(ArgumentError)
        end
      end

      context "when passed an invalid image" do
        before do
          expect(http_client).to receive(:get).with(
            "/account/images", "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(images_response)
        end
        it 'should raise an exception' do
          expect {
            servers.create("server1", 256, "RedHat")
          }.to raise_error(ArgumentError)
        end
      end

      context "when passed valid flavor and image" do
        before do
          expect(http_client).to receive(:get).with(
            "/account/flavors", "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(flavours_response)
          expect(http_client).to receive(:get).with(
            "/account/images", "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(images_response)
          post_body = JSON.dump({server: {name: "server1", imageRef: 112, flavorRef: 1}})
          expect(http_client).to receive(:post).with(
            "/account/servers", post_body, "Content-Type" => "application/json", "Accept" => "application/json"
          ).and_return(servers_response)
        end
        it 'should return a new Raca::Server with the correct ID' do
          server = servers.create("server1", 256, "LTS")
          expect(server).to be_a(Raca::Server)
          expect(server.server_id).to eq(456)
        end
      end

    end
  end
end
