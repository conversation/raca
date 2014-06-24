require 'spec_helper'

describe Raca::Account do
  let!(:username) { "theuser"}
  let!(:api_key) { "thekey" }
  let!(:api_response) {
    File.read(File.expand_path("../fixtures/identity_response.json", __FILE__))
  }

  describe '#auth_token' do
    context "when the token is pre-cached" do
      let!(:cache) { {"raca-theuser" => JSON.load(File.read(File.expand_path("../fixtures/identity_response_alt.json", __FILE__))) } }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        expect(info.auth_token).to eq("thetoken")
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
        expect(info.auth_token).to eq("secret")
      end
    end
  end

  describe '#public_endpoint' do
    context "when the storage url is pre-cached" do
      let!(:cache) { {"raca-theuser" => JSON.load(File.read(File.expand_path("../fixtures/identity_response_alt.json", __FILE__))) } }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      context "when the requested API is regioned" do
        context "and a region is provided" do
          it "should return the cached value" do
            expect(info.public_endpoint("cloudFiles", "ORD")).to eq("https://storage101.ord1.clouddrive.com/v1/foobar")
          end
        end
        context "and a region is not provided" do
          it "should raise an exception" do
            expect {
              info.public_endpoint("cloudFiles")
            }.to raise_error(
              ArgumentError, "The requested service exists in multiple regions, please specify a region code"
            )
          end
        end
      end
      context "when the requested API is not regioned" do
        context "and a region is not provided" do
          it "should return the cached value" do
            expect(info.public_endpoint("cloudDNS")).to eq("https://dns.api.rackspacecloud.com/v1.0/123456")
          end
        end
        context "and a region is provided" do
          it "should ignore the region and return the cached value" do
            expect(info.public_endpoint("cloudDNS", "ORD")).to eq("https://dns.api.rackspacecloud.com/v1.0/123456")
          end
        end
      end
      context "when the requested API does not exist" do
        context "and a region is not provided" do
          it "should raise an exception" do
            expect {
              info.public_endpoint("cloudFoo")
            }.to raise_error(
              ArgumentError, "No matching services found"
            )
          end
        end
        context "and a region is provided" do
          it "should raise an exception" do
            expect {
              info.public_endpoint("cloudFoo", "ORD")
            }.to raise_error(
              ArgumentError, "No matching services found"
            )
          end
        end
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
        uri = "https://storage101.ord1.clouddrive.com/v1/MossoCloudFS_3788b1b9-4be1-4fae-9bea-fe5c532dbe47"
        expect(info.public_endpoint("cloudFiles", "ORD")).to eq(uri)
      end
    end
  end

  describe '#service_names' do
    context "when the identity response is pre-cached" do
      let!(:cache) { {"raca-theuser" => JSON.load(File.read(File.expand_path("../fixtures/identity_response.json", __FILE__))) } }
      let!(:info) { Raca::Account.new(username, api_key, cache)}

      it "should return the cached value" do
        expect(info.service_names).to match_array(%w{
          cloudFilesCDN cloudFiles cloudServersOpenStack cloudBlockStorage
          cloudDatabases cloudDNS cloudLoadBalancers cloudMonitoring
          cloudQueues autoscale cloudBackup cloudServers
        })
      end
    end
  end
end
