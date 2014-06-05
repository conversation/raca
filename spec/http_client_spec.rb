require 'spec_helper'

describe Raca::HttpClient do
  let!(:account) {
    double(Raca::Account).tap { |account|
      allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
      allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
      allow(account).to receive(:auth_token).and_return('token')
      allow(account).to receive(:refresh_cache).and_return(true)
    }
  }
  let!(:client) {
    Raca::HttpClient.new(account, "the-cloud.com")
  }

  describe "#get" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:get, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.get("/foo")).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:get, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.get("/foo", 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
      context "with a block" do
        it "should yield Net::HTTPSuccess"
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:get, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'}
          ).to_return(:status => 401)
          stub_request(:get, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'}
          ).to_return(:status => 200, :body => "FooBar")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.get("/foo")).to be_a(Net::HTTPSuccess)
          expect(client.get("/foo").body).to eq("FooBar")
        end
      end
    end
    context "when the server times out" do
      before do
        stub_request(:get, "https://the-cloud.com/foo").with(
          :headers => {'X-Auth-Token'=>'token'}
        ).to_raise(Timeout::Error)
      end

      it "should transparently re-try and return Net::HTTPSuccess" do
        expect {
          client.get("/foo")
        }.to raise_error(Timeout::Error)
      end
    end
  end

  describe "#head" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:head, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.head("/foo")).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:head, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.head("/foo", 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:head, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'}
          ).to_return(:status => 401)
          stub_request(:head, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'}
          ).to_return(:status => 200)
        end

        it "should return Net::HTTPSuccess" do
          expect(client.head("/foo")).to be_a(Net::HTTPSuccess)
        end
      end
    end
  end

  describe "#delete" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:delete, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.delete("/foo")).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:delete, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.delete("/foo", 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:delete, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'}
          ).to_return(:status => 401)
          stub_request(:delete, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'}
          ).to_return(:status => 200)
        end

        it "should return Net::HTTPSuccess" do
          expect(client.delete("/foo")).to be_a(Net::HTTPSuccess)
        end
      end
    end
  end

  describe "#put" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.put("/foo")).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.put("/foo", 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'}
          ).to_return(:status => 401)
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'}
          ).to_return(:status => 200)
        end

        it "should return Net::HTTPSuccess" do
          expect(client.put("/foo")).to be_a(Net::HTTPSuccess)
        end
      end
    end
  end

  describe "#streaming_put" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'},
            :body => "Body"
          ).to_return(:status => 200, :body => "")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.streaming_put("/foo", StringIO.new("Body"), 4)).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'},
            :body => "Body"
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.streaming_put("/foo", StringIO.new("Body"), 4, 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'},
            :body => "Body"
          ).to_return(:status => 401)
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'},
            :body => "Body"
          ).to_return(:status => 200)
        end

        it "should return Net::HTTPSuccess" do
          expect(client.streaming_put("/foo", StringIO.new("Body"), 4)).to be_a(Net::HTTPSuccess)
        end
      end
    end
  end

  describe "#post" do
    context "when the server returns 200" do
      context "with no headers" do
        before do
          stub_request(:post, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'},
            :body => "Body"
          ).to_return(:status => 200, :body => "")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.post("/foo", "Body")).to be_a(Net::HTTPSuccess)
        end
      end

      context "with no body" do
        before do
          stub_request(:post, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token'},
            :body => ""
          ).to_return(:status => 200, :body => "")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.post("/foo", nil)).to be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:post, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'},
            :body => "Body"
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          expect(client.post("/foo", "Body", 'Content-Type' => 'text/plain')).to be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            allow(account).to receive(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            allow(account).to receive(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            allow(account).to receive(:auth_token).and_return('stale_token','fresh_token')
            allow(account).to receive(:refresh_cache).and_return(true)
          }
        }
        let!(:client) {
          Raca::HttpClient.new(account, "the-cloud.com")
        }

        before do
          stub_request(:post, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'stale_token'},
            :body => "Body"
          ).to_return(:status => 401)
          stub_request(:post, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'fresh_token'},
            :body => "Body"
          ).to_return(:status => 200)
        end

        it "should return Net::HTTPSuccess" do
          expect(client.post("/foo", "Body")).to be_a(Net::HTTPSuccess)
        end
      end
    end
  end

end
