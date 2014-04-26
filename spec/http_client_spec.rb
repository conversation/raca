require 'spec_helper'

describe Raca::HttpClient do
  let!(:account) {
    double(Raca::Account).tap { |account|
      account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
      account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
      account.stub(:auth_token).and_return('token')
      account.stub(:refresh_cache).and_return(true)
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
          client.get("/foo").should be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:get, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          client.get("/foo", 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
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
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.get("/foo").should be_a(Net::HTTPSuccess)
          client.get("/foo").body.should == "FooBar"
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
        lambda {
          client.get("/foo")
        }.should raise_error(Timeout::Error)
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
          client.head("/foo").should be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:head, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          client.head("/foo", 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.head("/foo").should be_a(Net::HTTPSuccess)
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
          client.delete("/foo").should be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:delete, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          client.delete("/foo", 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.delete("/foo").should be_a(Net::HTTPSuccess)
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
          client.put("/foo").should be_a(Net::HTTPSuccess)
        end
      end

      context "with a custom header" do
        before do
          stub_request(:put, "https://the-cloud.com/foo").with(
            :headers => {'X-Auth-Token'=>'token', 'Content-Type' => 'text/plain'}
          ).to_return(:status => 200, :body => "The Body")
        end

        it "should return Net::HTTPSuccess" do
          client.put("/foo", 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.put("/foo").should be_a(Net::HTTPSuccess)
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
          client.streaming_put("/foo", StringIO.new("Body"), 4).should be_a(Net::HTTPSuccess)
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
          client.streaming_put("/foo", StringIO.new("Body"), 4, 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.streaming_put("/foo", StringIO.new("Body"), 4).should be_a(Net::HTTPSuccess)
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
          client.post("/foo", "Body").should be_a(Net::HTTPSuccess)
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
          client.post("/foo", nil).should be_a(Net::HTTPSuccess)
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
          client.post("/foo", "Body", 'Content-Type' => 'text/plain').should be_a(Net::HTTPSuccess)
        end
      end
    end
    context "when the server returns 401 and we retry with a new auth token" do
      context "with no headers" do
        let!(:account) {
          double(Raca::Account).tap { |account|
            account.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
            account.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
            account.stub(:auth_token).and_return('stale_token','fresh_token')
            account.stub(:refresh_cache).and_return(true)
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
          client.post("/foo", "Body").should be_a(Net::HTTPSuccess)
        end
      end
    end
  end

end
