require 'spec_helper'

describe Raca::Account do
  let!(:username) { "theuser"}
  let!(:api_key) { "thekey" }
  let!(:api_response) {
    File.read(File.expand_path("../fixtures/identity_response.json", __FILE__))
  }

  describe '#auth_token' do
    context "when the token is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => JSON.load(File.read(File.expand_path("../fixtures/identity_response_alt.json", __FILE__))) } }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.auth_token.should == "thetoken"
      end
    end
    context "when the identity response isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => api_response)
      end
      it "should request the value from rackspace" do
        info.auth_token.should == "secret"
      end
    end
  end

  describe '#public_endpoint' do
    context "when the storage url is pre-cached" do
      let!(:cache) { {"cloudfiles-data" => JSON.load(File.read(File.expand_path("../fixtures/identity_response_alt.json", __FILE__))) } }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        info.public_endpoint("cloudFiles", "ORD").should == "https://storage101.ord1.clouddrive.com/v1/foobar"
      end
    end
    context "when the storage url isn't pre-cached" do
      let!(:info) { Raca::Account.new(username, api_key, {})}

      before do
        WebMock.stub_request(:post, "https://identity.api.rackspacecloud.com/v2.0/tokens")
          .with('Content-Type'=>'application/json')
          .to_return(:status => 200, :body => api_response)
      end
      it "should request the value from rackspace" do
        info.public_endpoint("cloudFiles", "ORD").should == "https://storage101.ord1.clouddrive.com/v1/MossoCloudFS_3788b1b9-4be1-4fae-9bea-fe5c532dbe47"
      end
    end
  end
end
