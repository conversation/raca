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
        Raca::Server.new(account, :ord, "server1")
      }
      it 'should set the server_name atttribute' do
        server.server_name.should == 'server1'
      end

      it 'should set the server_id atttribute' do
        server.server_id.should == 123
      end
    end

    context "with an new server" do
      let!(:server) {
        Raca::Server.new(account, :ord, "server2")
      }
      it 'should set the server_name atttribute' do
        server.server_name.should == 'server2'
      end

      it 'should set the server_id atttribute' do
        server.server_id.should be_nil
      end
    end

  end

  describe '#exists?' do
    context "with an existing server" do
      let!(:server) {
        Raca::Server.new(account, :ord, "server1")
      }

      it 'should return true' do
        server.exists?.should be_true
      end
    end

    context "with an new server" do
      let!(:server) {
        Raca::Server.new(account, :ord, "server2")
      }

      it 'should return false' do
        server.exists?.should be_false
      end
    end
  end

  describe '#create' do

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "server1") }

      it 'should return raise an exception' do
        lambda {
          server.create(1024, "LTS")
        }.should raise_error(ArgumentError)
      end
    end

    context "with an new server" do
      let!(:server) { Raca::Server.new(account, :ord, "server2") }

      it 'should raise an exception when passed an invalid flavour' do
        lambda {
          server.create(1024, "LTS")
        }.should raise_error(ArgumentError)
      end

      it 'should raise an exception when passed an invalid image' do
        lambda {
          server.create(256, "RedHat")
        }.should raise_error(ArgumentError)
      end

      it 'should return the ID of the new server' do
        server.create(256, "LTS").should == 456
      end

      it 'should store the ID of the new server' do
        server.server_id.should be_nil
        server.create(256, "LTS")
        server.server_id.should == 456
      end
    end
  end

  describe '#details' do

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "server1") }

      it 'should return a hash of interesting data' do
        server.details.should be_a(Hash)
        server.details["status"].should == "ACTIVE"
      end
    end

    context "with a new server" do
      let!(:server) { Raca::Server.new(account, :ord, "server2") }

      it 'should raise an exception' do
        lambda {
          server.details
        }.should raise_error(ArgumentError)
      end

    end
  end

  describe '#delete!' do

    context "with an existing server" do
      let!(:server) { Raca::Server.new(account, :ord, "server1") }

      it 'should return true' do
        server.delete!.should be_true
      end
    end

    context "with a new server" do
      let!(:server) { Raca::Server.new(account, :ord, "server2") }

      it 'should raise an exception' do
        lambda {
          server.delete!
        }.should raise_error(ArgumentError)
      end

    end
  end
end
