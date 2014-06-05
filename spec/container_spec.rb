require 'spec_helper'

describe Raca::Container do

  describe '#initialization' do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
      info.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
      info.stub(:auth_token).and_return('token')
      info.stub(:refresh_cache).and_return(true)
      info
    }

    it 'should raise an argument error if the supplied container name contains a "/"' do
      lambda { Raca::Container.new(account, :ord, 'a_broken_container_name/') }.should raise_error(ArgumentError)
    end

    it 'should set the container_name atttribute' do
      container = 'mah_buckit'
      Raca::Container.new(account, :ord, container).container_name.should eql(container)
    end

  end

  describe 'instance method: ' do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
      info.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
      info.stub(:auth_token).and_return('token')
      info.stub(:refresh_cache).and_return(true)
      info
    }
    let!(:storage_client) {
      Raca::HttpClient.new(account, "the-cloud.com")
    }
    let!(:cdn_client) {
      Raca::HttpClient.new(account, "cdn.the-cloud.com")
    }
    let!(:logger) { double(Object).as_null_object }
    let!(:cloud_container) { Raca::Container.new(account, :ord, 'test', logger: logger) }

    describe '#upload' do
      context 'with a StringIO object' do
        context 'with no headers provided and no file extension' do
          let(:data_or_path) { StringIO.new('some string', 'r') }

          before(:each) do
            account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
            storage_client.should_receive(:streaming_put).with(
              "/account/test/key", kind_of(StringIO), 11, 'Content-Type'=>'application/octet-stream', 'ETag' => '5ac749fbeec93607fc28d666be85e73a'
            ).and_return(
              Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
                response.add_field('ETag', 'foo')
              }
            )
          end

          it "should return the ETag header returned from rackspace" do
            cloud_container.upload('key', data_or_path).should == 'foo'
          end
        end
        context 'with no headers provided and a file extension on the key' do
          let(:data_or_path) { StringIO.new('some string', 'r') }

          before(:each) do
            account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
            storage_client.should_receive(:streaming_put).with(
              "/account/test/key.zip", kind_of(StringIO), 11, 'Content-Type'=>'application/zip', 'ETag' => '5ac749fbeec93607fc28d666be85e73a'
            ).and_return(
              Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
                response.add_field('ETag', 'foo')
              }
            )
          end

          it "should return the ETag header returned from rackspace" do
            cloud_container.upload('key.zip', data_or_path).should == 'foo'
          end
        end
        context 'with a content-type header provided' do
          let(:data_or_path) { StringIO.new('some string', 'r') }

          before(:each) do
            account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
            storage_client.should_receive(:streaming_put).with(
              "/account/test/key", kind_of(StringIO), 11, 'Content-Type'=>'text/plain', 'ETag' => '5ac749fbeec93607fc28d666be85e73a'
            ).and_return(
              Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
                response.add_field('ETag', 'foo')
              }
            )
          end

          it "should return the ETag header returned from rackspace" do
            cloud_container.upload('key', data_or_path, 'Content-Type' => 'text/plain').should == 'foo'
          end
        end
        context 'with a space in the object path' do
          let(:data_or_path) { StringIO.new('some string', 'r') }

          before(:each) do
            account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
            storage_client.should_receive(:streaming_put).with(
              "/account/test/chunky%20bacon.txt", kind_of(StringIO), 11, 'Content-Type'=>'text/plain', 'ETag' => '5ac749fbeec93607fc28d666be85e73a'
            ).and_return(
              Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
                response.add_field('ETag', 'foo')
              }
            )
          end

          it "should return the ETag header returned from rackspace" do
            cloud_container.upload('chunky bacon.txt', data_or_path).should == 'foo'
          end
        end
      end

      context 'with a File object' do
        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key", kind_of(File), 0, 'Content-Type'=>'text/plain', 'ETag' => 'd41d8cd98f00b204e9800998ecf8427e'
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', 'foo')
            }
          )
        end

        it "should return the ETag header returned from rackspace" do
          File.open(File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt'), 'r') do |data_or_path|
            cloud_container.upload('key', data_or_path).should == 'foo'
          end
        end
      end

      context 'with a String object' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key", kind_of(File), 0, 'Content-Type'=>'text/plain', 'ETag' => 'd41d8cd98f00b204e9800998ecf8427e'
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', 'foo')
            }
          )
        end

        it "should return the ETag header returned from rackspace" do
          cloud_container.upload('key', data_or_path).should == 'foo'
        end
      end

      context 'with a String object that exceeds than the large file threshold' do
        let(:data_or_path) { StringIO.new("abcdefg") }

        before do
          stub_const("Raca::Container::LARGE_FILE_THRESHOLD", 3)
          stub_const("Raca::Container::LARGE_FILE_SEGMENT_SIZE", 3)
        end

        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key.000", kind_of(StringIO), 3, 'Content-Type'=>'application/octet-stream', 'ETag' => '900150983cd24fb0d6963f7d28e17f72'
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', '1')
            }
          )
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key.001", kind_of(StringIO), 3, 'Content-Type'=>'application/octet-stream', 'ETag' => '4ed9407630eb1000c0f6b63842defa7d'
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', '2')
            }
          )
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key.002", kind_of(StringIO), 1, 'Content-Type'=>'application/octet-stream', 'ETag' => 'b2f5ff47436671b6e533d8dc3614845d'
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', '3')
            }
          )

          json  = '[{"path":"test/key.000","etag":"1","size_bytes":3},'
          json += '{"path":"test/key.001","etag":"2","size_bytes":3},'
          json += '{"path":"test/key.002","etag":"3","size_bytes":1}]'
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key?multipart-manifest=put", string_io_containing(json), 151, {}
          ).and_return(
            Net::HTTPSuccess.new("1.1", 200, "OK").tap { |response|
              response.add_field('ETag', '1234')
            }
          )
        end

        it "should return the ETag header returned from rackspace" do
          cloud_container.upload('key', data_or_path).should == "1234"
        end
      end

      context 'with a String object when Rackspace times out' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          storage_client.should_receive(:streaming_put).with(
            "/account/test/key", kind_of(File), 0, 'Content-Type'=>'text/plain', 'ETag' => 'd41d8cd98f00b204e9800998ecf8427e'
          ).and_raise(Raca::TimeoutError)
        end

        it "should bubble the same error up" do
          lambda {
            cloud_container.upload('key', data_or_path)
          }.should raise_error(Raca::TimeoutError)
        end
      end

      context 'with another type of object' do
        let(:data_or_path) { 4 }

        it 'should raise an argument error' do
          lambda { cloud_container.upload('key', data_or_path) }.should raise_error(ArgumentError)
        end
      end
    end

    describe '#delete' do
      before(:each) do
        account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
        storage_client.should_receive(:delete).with("/account/test/key").and_return(Net::HTTPSuccess.new("1.1", 200, "OK"))
      end

      it 'should log the fact that it deleted the key' do
        logger.should_receive(:debug).with('deleting key from /account/test')
        cloud_container.delete('key')
      end

      it 'should return true' do
        result = cloud_container.delete('key').should == true
      end
    end

    describe '#purge_from_akamai' do
      before(:each) do
        account.should_receive(:http_client).with("cdn.the-cloud.com").and_return(cdn_client)
        cdn_client.should_receive(:delete).with(
          "/account/test/key",
          "X-Purge-Email" => "services@theconversation.edu.au"
        ).and_return(Net::HTTPSuccess.new("1.1", 200, "OK"))
      end

      it 'should log the fact that it deleted the key' do
        logger.should_receive(:debug).with('Requesting /account/test/key to be purged from the CDN')
        cloud_container.purge_from_akamai('key', 'services@theconversation.edu.au')
      end

      it 'should return true' do
        result = cloud_container.purge_from_akamai('key', 'services@theconversation.edu.au').should == true
      end
    end

    describe '#object_metadata' do
      before(:each) do
        account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
        response = Net::HTTPSuccess.new("1.1", 200, "OK")
        response.add_field('Content-Length', '12345')
        response.add_field('Content-Type', 'text/plain')
        storage_client.should_receive(:head).with("/account/test/key").and_return(response)
      end

      it 'should log the fact that it is about to download key' do
        logger.should_receive(:debug).with('Requesting metadata from /account/test/key')
        cloud_container.object_metadata('key')
      end

      it 'should return appropriate metadata as a hash' do
        cloud_container.object_metadata('key').should == {
          bytes: 12345,
          content_type: 'text/plain'
        }
      end
    end

    describe '#download' do
      context 'requesting an object that exists' do
        let!(:body) { "The response has this as the body\n" }
        let!(:filepath) { File.join(File.dirname(__FILE__), '../tmp', 'cloud_container_test_file') }

        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          response = double("Net::HTTPSuccess")
          response.should_receive(:read_body).with(no_args()).and_yield(body)
          response.should_receive(:[]).with("Content-Length").and_return(33)
          storage_client.should_receive(:get).with("/account/test/key").and_yield(response).and_return(response)

          FileUtils.mkdir_p File.dirname(filepath)
        end

        it 'should log the fact that it is about to download key' do
          logger.should_receive(:debug).with('downloading key from /account/test')
          cloud_container.download('key', filepath)
        end

        it 'should write the response body to disk' do
          cloud_container.download('key', filepath)
          File.read(filepath).should == body
        end

        it 'should return the number of bytes downloaded' do
          cloud_container.download('key', filepath).should == 33
        end

        after(:each) do
          File.delete(filepath) if File.exists?(filepath)
        end
      end

      context "requesting an object that doesn't exist" do
        before(:each) do
          account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
          storage_client.should_receive(:get).with("/account/test/key").and_raise(Raca::NotFoundError)
        end

        it 'should bubble up the same error' do
          logger.should_receive(:debug).with('downloading key from /account/test')
          lambda {
            cloud_container.download('key', @filepath)
          }.should raise_error(Raca::NotFoundError)
        end
      end
    end

    describe '#list' do
      before(:each) do
        account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
      end
      context 'requesting fewer items than the max per list API call' do
        let(:max) { 1 }

        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=1").and_return(
            double("Net::HTTPSuccess", body: "The response has this as the body\n")
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 items from /account/test")
          cloud_container.list(max: max)
        end

        it 'should be an array of length requested' do
          cloud_container.list(max: max).length.should eql(max)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; we don't need any more.")
          cloud_container.list(max: max)
        end
      end

      context 'returns fewer results than the maximum asked for' do
        let(:max) { 100000 }

        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=10000").and_return(
            double("Net::HTTPSuccess", body: "The response has this as the body\n")
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 100000 items from /account/test")
          cloud_container.list(max: max)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max).length.should eql(1)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; there can't be any more.")
          cloud_container.list(max: max)
        end
      end

      context 'returns fewer items than requested and recursively requests more' do
        let(:max) { 10001 }

        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=10000").and_return(
            double("Net::HTTPSuccess", body: "The response has this as the body\n"*10_000)
          )
          storage_client.should_receive(:get).with("/account/test?limit=1&marker=The%20response%20has%20this%20as%20the%20body").and_return(
            double("Net::HTTPSuccess", body: "The response has this as the body\n")
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 10001 items from /account/test")
          cloud_container.list(max: max)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max).length.should eql(10001)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 10000 items; requesting 10000 more.")
          cloud_container.list(max: max)
        end
      end

      context 'returns only results with a certain prefix' do
        let(:max) { 1 }
        let(:prefix) { "assets/"}

        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=1&prefix=assets/").and_return(
            double("Net::HTTPSuccess", body: "assets/foo.css\n")
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 items from /account/test")
          cloud_container.list(max: max, prefix: prefix)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max, prefix: prefix).length.should eql(1)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; we don't need any more.")
          cloud_container.list(max: max, prefix: prefix)
        end
      end
      context 'when a detailed list is requested' do
        let(:max) { 1 }
        let(:prefix) { "assets/"}
        let(:result) {
          [{
            "hash"=>"af580187547b398e9bca73f936643dc5",
            "last_modified"=>"2013-08-06T05:01:17.769500",
            "bytes"=>56,
            "name"=>"csv/2.csv",
            "content_type"=>"text/csv"
          }]
        }

        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=1&format=json").and_return(
            double("Net::HTTPSuccess", body: JSON.dump(result))
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 items from /account/test")
          cloud_container.list(max: max, details: true)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max, details: true).length.should eql(1)
        end

        it 'should be an array of hashes with appropriate data' do
          detail = cloud_container.list(max: max, details: true).first
          detail.should include("hash" => "af580187547b398e9bca73f936643dc5")
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; we don't need any more.")
          cloud_container.list(max: max, details: true)
        end
      end
      context 'when a detailed list is requested and the results are paged' do
        let(:max) { 10001 }
        let(:result) {
          {
            "hash"=>"af580187547b398e9bca73f936643dc5",
            "last_modified"=>"2013-08-06T05:01:17.769500",
            "bytes"=>56,
            "name"=>"csv/2.csv",
            "content_type"=>"text/csv"
          }
        }
        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=10000&format=json").and_return(
            double("Net::HTTPSuccess", body: JSON.dump((1..10000).map {result}))
          )
          storage_client.should_receive(:get).with("/account/test?limit=1&marker=csv/2.csv&format=json").and_return(
            double("Net::HTTPSuccess", body: JSON.dump([result]))
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 10001 items from /account/test")
          cloud_container.list(max: max, details: true)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max, details: true).length.should eql(10001)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 10000 items; requesting 10000 more.")
          cloud_container.list(max: max, details: true)
        end
      end
    end

    describe '#search' do
      let(:search_term) { 'foo' }

      before(:each) do
        account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
      end

      context '3 results found' do
        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=10000&prefix=foo").and_return(
            double("Net::HTTPSuccess", body: "result\n"*3)
          )
        end

        it 'should log what it indends to do' do
          logger.should_receive(:debug).with("retrieving container listing from /account/test items starting with #{search_term}")
          cloud_container.search(search_term)
        end

        it 'should return an array of search results' do
          cloud_container.search(search_term).length.should eql(3)
        end
      end

      context 'no results found' do
        before(:each) do
          storage_client.should_receive(:get).with("/account/test?limit=10000&prefix=foo").and_return(
            double("Net::HTTPSuccess", body: "")
          )
        end

        it 'should log what it indends to do' do
          logger.should_receive(:debug).with("retrieving container listing from /account/test items starting with #{search_term}")
          cloud_container.search(search_term)
        end

        it 'should return an empty array of search results' do
          cloud_container.search(search_term).should eql([])
        end
      end
    end

    describe '#metadata' do
      before(:each) do
        account.should_receive(:http_client).with("the-cloud.com").and_return(storage_client)
      end
      context "with a simple container name" do
        before(:each) do
          response = Net::HTTPSuccess.new("1.1", 200, "OK")
          response.add_field('X-Container-Object-Count', '5')
          response.add_field('X-Container-Bytes-Used', '1200')
          storage_client.should_receive(:head).with("/account/test").and_return(
            response
          )
        end

        it 'should log what it indends to do' do
          logger.should_receieve(:debug).with('retrieving container metadata from /account/test')
          cloud_container.metadata
        end

        it 'should return a hash containing the number of objects and the total bytes used' do
          cloud_container.metadata.should eql({:objects => 5, :bytes => 1200})
        end
      end
      context "with a container name containing spaces" do
        let!(:cloud_container) { Raca::Container.new(account, :ord, 'foo bar') }

        before(:each) do
          response = Net::HTTPSuccess.new("1.1", 200, "OK")
          response.add_field('X-Container-Object-Count', '5')
          response.add_field('X-Container-Bytes-Used', '1200')
          storage_client.should_receive(:head).with("/account/foo%20bar").and_return(
            response
          )
        end

        it 'should log what it indends to do' do
          logger.should_receieve(:debug).with('retrieving container metadata from /account/foo bar')
          cloud_container.metadata
        end

        it 'should return a hash containing the number of objects and the total bytes used' do
          cloud_container.metadata.should eql({:objects => 5, :bytes => 1200})
        end
      end
    end

    describe '#cdn_metadata' do
      before(:each) do
        account.should_receive(:http_client).with("cdn.the-cloud.com").and_return(cdn_client)
        response = Net::HTTPSuccess.new("1.1", 200, "OK")
        response.add_field('X-CDN-Enabled', 'True')
        response.add_field('X-CDN-URI', "http://example.com")
        response.add_field("X-CDN-STREAMING-URI", "http://streaming.example.com")
        response.add_field("X-CDN-SSL-URI", "https://example.com")
        response.add_field("X-TTL", "1234")
        response.add_field("X-Log-Retention", "False")
        cdn_client.should_receive(:head).with("/account/test").and_return(
          response
        )
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('retrieving container CDN metadata from /account/test')
        cloud_container.cdn_metadata
      end

      it 'should return a hash containing the number of objects and the total bytes used' do
        cloud_container.cdn_metadata.tap { |response|
          response[:cdn_enabled].should    == true
          response[:host].should           == "http://example.com"
          response[:ssl_host].should       == "https://example.com"
          response[:streaming_host].should == "http://streaming.example.com"
          response[:ttl].should            == 1234
          response[:log_retention].should  == false
        }
      end
    end

    describe '#cdn_enable' do
      before(:each) do
        account.should_receive(:http_client).with("cdn.the-cloud.com").and_return(cdn_client)
        cdn_client.should_receive(:put).with("/account/test", "X-TTL" => "60000").and_return(
          Net::HTTPCreated.new("1.1", 201, "OK")
        )
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('enabling CDN access to /account/test with a cache expiry of 1000 minutes')
        cloud_container.cdn_enable(60000)
      end

      it 'should return true' do
        cloud_container.cdn_enable(60000).should == true
      end
    end
    describe '#temp_url' do
      context 'when the object name has no spaces' do
        it 'should returned a signed URL' do
          url = cloud_container.temp_url("foo.txt", "secret", 1234567890)
          expected = "https://the-cloud.com/account/test/foo.txt?temp_url_sig=596355666ef72a9da6b03de32e9dd4ac003ee9be&temp_url_expires=1234567890"
          url.should == expected
        end
      end
      context 'when the object name has a spaces' do
        it 'should returned a signed URL' do
          url = cloud_container.temp_url("foo bar.txt", "secret", 1234567890)
          exp = "https://the-cloud.com/account/test/foo%20bar.txt?temp_url_sig=cf817a7dcd409b40c65da11653a1652b62fe44fe&temp_url_expires=1234567890"
          url.should == exp
        end
      end
    end
    describe '#temp_upload_url' do
      context 'when the object name has no spaces' do
        it 'should returned a signed URL' do
          url = cloud_container.temp_upload_url("foo.txt", "secret", 1234567890)
          expected = "https://the-cloud.com/account/test/foo.txt?temp_url_sig=3c0fc25790a9238f84b6cb34574f454cdcd94d03&temp_url_expires=1234567890"
          url.should == expected
        end
      end
      context 'when the object name has a spaces' do
        it 'should returned a signed URL' do
          url = cloud_container.temp_upload_url("foo bar.txt", "secret", 1234567890)
          exp = "https://the-cloud.com/account/test/foo%20bar.txt?temp_url_sig=ff857d49eced54b42be6079498af1a1ae3f0561c&temp_url_expires=1234567890"
          url.should == exp
        end
      end
    end
  end
end
