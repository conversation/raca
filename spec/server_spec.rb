require 'spec_helper'
require 'webmock/rspec'

describe Raca::Server do
  let!(:account) {
    info = double(Raca::Account)
    info.stub(:public_endpoint).with("cloudServersOpenStack", :ord).and_return("https://the-cloud.com/account")
    info.stub(:auth_token).and_return('token')
    info.stub(:refresh_cache).and_return(true)
    info
  }

  before(:each) do

    stub_request(:get, "https://the-cloud.com/account/servers/123").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(
      :status => 200,
      :body => JSON.dump(
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

    stub_request(:delete, "https://the-cloud.com/account/servers/123").with(
      :headers => {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Auth-Token'=>'token'
      }
    ).to_return(:status => 204, :body => '')
  end

  describe '#initialization' do

    context "with an existing server" do
      let!(:server) {
        Raca::Server.new(account, :ord, "123")
      }

      it 'should set the server_id atttribute' do
        server.server_id.should == "123"
      end
    end

  end

  describe '#details' do

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "123") }

      it 'should return a hash of interesting data' do
        server.details.should be_a(Hash)
        server.details["status"].should == "ACTIVE"
      end
    end
  end

  describe '#delete!' do

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "123") }

      it 'should return true' do
        server.delete!.should be_true
      end
    end

  end
end
