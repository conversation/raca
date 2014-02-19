require 'spec_helper'

describe Raca::Account do
  let!(:username) { "theuser"}
  let!(:api_key) { "thekey" }
  let!(:api_response) {
    {access: {
      token: {
        id: "bar"
      },
      serviceCatalog: [
        {name: 'cloudFiles', endpoints: [{region: "ORD", publicURL: "http://cloudfiles.com/filespath"}]},
        {name: 'cloudFilesCDN', endpoints: [{region: "ORD", publicURL: "http://cloudcdn.com/cdnpath"}]},
        {name: 'cloudServers', endpoints: [{publicURL: "http://cloudservers.com/serverpath"}]},
        {name: 'cloudServersOpenStack', endpoints: [{region: "ORD", publicURL: "http://ngcloudservers.com/ngserverpath"}]},
      ]
      }
    }
  }
  let!(:json_response) { JSON.dump(api_response) }

  describe '#auth_token' do
    context "when the token is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {auth_token: "foo"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.auth_token.should == "foo"
      end
    end
    context "when the token isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.auth_token.should == "bar"
      end
    end
  end

  describe '#storage_host' do
    context "when the storage url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {storage_url: "https://example.com/foo"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.storage_host.should == "example.com"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.storage_host.should == "cloudfiles.com"
      end
    end
  end

  describe '#cdn_host' do
    context "when the cdn url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {cdn_url: "https://example.com/foo"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.cdn_host.should == "example.com"
      end
    end
    context "when the cdn url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.cdn_host.should == "cloudcdn.com"
      end
    end
  end

  describe '#path' do
    context "when the storage url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {storage_url: "https://example.com/filepath"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.path.should == "/filepath"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.path.should == "/filespath"
      end
    end
  end

  describe '#server_host' do
    context "when the server url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {server_url: "https://example.com/serverpath"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.server_host.should == "example.com"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.server_host.should == "cloudservers.com"
      end
    end
  end

  describe '#server_path' do
    context "when the server url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {server_url: "https://example.com/serverpath"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.server_path.should == "/serverpath"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.server_path.should == "/serverpath"
      end
    end
  end

  describe '#ngserver_host' do
    context "when the server url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {ngserver_url: "https://example.com/ngserverpath"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.ngserver_host.should == "example.com"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.ngserver_host.should == "ngcloudservers.com"
      end
    end
  end

  describe '#ngserver_path' do
    context "when the server url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => {ngserver_url: "https://example.com/ngserverpath"}} }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.ngserver_path.should == "/ngserverpath"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => json_response)
      end
      it "should request the value from rackspace" do
        info.ngserver_path.should == "/ngserverpath"
      end
    end
  end
end
