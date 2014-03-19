require 'spec_helper'
require 'webmock/rspec'

describe Raca::Servers do
  let!(:account) {
    info = double(Raca::Account)
    info.stub(:public_endpoint).with("cloudServersOpenStack", :ord).and_return("https://the-cloud.com/account")
    info.stub(:auth_token).and_return('token')
    info.stub(:refresh_cache).and_return(true)
    info
  }

  before(:each) do
    stub_request(:get, "https://the-cloud.com/account/servers").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(:status => 200, :body => '{"servers":[{"id":123,"name":"server1"}]}')

    stub_request(:get, "https://the-cloud.com/account/flavors").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(
      :status => 200,
      :body => JSON.dump({flavors: [{id:1,name:"256 server"},{id:2,name:"512 server"}]})
    )

    stub_request(:get, "https://the-cloud.com/account/images").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(
      :status => 200,
      :body => JSON.dump(
        {images:[{id:112,name:"Ubuntu 10.04 LTS"},{id:104,name:"Debian 6 (Squeeze)"}]}
      )
    )

    stub_request(:post, "https://the-cloud.com/account/servers").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(
      :status => 200,
      :body => JSON.dump(
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
  end

  describe '#create' do

    context "with an new server" do
      let!(:servers) { Raca::Servers.new(account, :ord) }

      it 'should raise an exception when passed an invalid flavour' do
        lambda {
          servers.create("server1", 1024, "LTS")
        }.should raise_error(ArgumentError)
      end

      it 'should raise an exception when passed an invalid image' do
        lambda {
          servers.create("server1", 256, "RedHat")
        }.should raise_error(ArgumentError)
      end

      it 'should return a new Raca::Server with the correct ID' do
        server = servers.create("server1", 256, "LTS")
        server.should be_a(Raca::Server)
        server.server_id.should == 456
      end

    end
  end
end
