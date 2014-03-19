require 'spec_helper'

describe Raca::Container do

  describe "MAX_ITEMS_PER_LIST" do
    subject { Raca::Container::MAX_ITEMS_PER_LIST }
    it { should eql(10_000) }
  end

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

  # This spec could be written for any public method on Raca::Container. The point
  # is to test the automatic retry after receiving a 401 response, not to test the
  # metadata method itself
  describe "metadata request with stale auth details" do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
      info.stub(:public_endpoint).with("cloudFilesCDN", :ord).and_return("https://cdn.the-cloud.com/account")
      info.stub(:auth_token).and_return('stale_token','fresh_token')
      info.stub(:refresh_cache).and_return(true)
      info
    }
    let!(:cloud_container) { Raca::Container.new(account, :ord, 'test') }

    before(:each) do
      stub_request(:head, "https://the-cloud.com/account/test").with(
        :headers => {'X-Auth-Token'=>'stale_token'}
      ).to_return(:status => 401, :body => "")
      stub_request(:head, "https://the-cloud.com/account/test").with(
        :headers => {'X-Auth-Token'=>'fresh_token'}
      ).to_return(
        :status => 200,
        :headers => {'X-Container-Object-Count' => 5, 'X-Container-Bytes-Used' => 1200}
      )
    end

    it "should automatically re-auth and try again" do
      cloud_container.metadata.should eql({:objects => 5, :bytes => 1200})
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
    let!(:logger) { double(Object).as_null_object }
    let!(:cloud_container) { Raca::Container.new(account, :ord, 'test', logger: logger) }

    describe '#upload' do
      context 'with a StringIO object' do
        let(:data_or_path) { StringIO.new('some string', 'r') }

        before(:each) do
          stub_request(:put, "https://the-cloud.com/account/test/key").with(
            :body => "some string",
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'11',
              'Content-Type'=>'application/octet-stream',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {'ETag' => 'foo'})
        end

        it "should return the ETag header returned from rackspace" do
          cloud_container.upload('key', data_or_path).should == 'foo'
        end
      end

      context 'with a File object' do
        before(:each) do
          stub_request(:put, "https://the-cloud.com/account/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'0',
              'Content-Type'=>'text/plain',
              'Etag'=>'d41d8cd98f00b204e9800998ecf8427e',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {'ETag' => 'foo'})
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
          stub_request(:put, "https://the-cloud.com/account/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'0',
              'Content-Type'=>'text/plain',
              'Etag'=>'d41d8cd98f00b204e9800998ecf8427e',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {'ETag' => 'foo'})
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
          stub_request(:put, "https://the-cloud.com/account/test/key.000").with(
            :headers => {
              'Content-Length'=>'3',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "1" })
          stub_request(:put, "https://the-cloud.com/account/test/key.001").with(
            :headers => {
              'Content-Length'=>'3',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "2" })
          stub_request(:put, "https://the-cloud.com/account/test/key.002").with(
            :headers => {
              'Content-Length'=>'1',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "3" })
          stub_request(:put, "https://the-cloud.com/account/test/key?multipart-manifest=put").with(
            :body => %Q{[{"path":"test/key.000","etag":"1","size_bytes":3},
                         {"path":"test/key.001","etag":"2","size_bytes":3},
                         {"path":"test/key.002","etag":"3","size_bytes":1}]}.gsub(/\s+/m,""),
            :headers => {
              'Content-Length'=>'151',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {"ETag" => "1234"})
        end#

        it "should return the ETag header returned from rackspace" do
          cloud_container.upload('key', data_or_path).should == "1234"
        end
      end

      context 'with a String object when Rackspace times out' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          stub_const("Raca::Container::RETRY_PAUSE", 0)

          stub_request(:put, "https://the-cloud.com/account/test/key").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_raise(Timeout::Error, Timeout::Error).then.to_return(
            :status => 200, :body => "", :headers => {"ETag" => "foo"}
          )
        end

        it "should return the ETag header returned from rackspace" do
          cloud_container.upload('key', data_or_path).should == 'foo'
        end
      end

      context 'with a String object when Rackspace times out four times' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          stub_const("Raca::Container::RETRY_PAUSE", 0)

          stub_request(:put, "https://the-cloud.com/account/test/key").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_raise(Timeout::Error, Timeout::Error, Timeout::Error, Timeout::Error)
        end

        it "should raise a descriptive execption" do
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
        stub_request(:delete, "https://the-cloud.com/account/test/key").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(:status => 200, :body => "", :headers => {})
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
        stub_request(:delete, "https://cdn.the-cloud.com/account/test/key").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token',
            'X-Purge-Email' => 'services@theconversation.edu.au'
          }
        ).to_return(:status => 200, :body => "", :headers => {})
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
        stub_request(:head, "https://the-cloud.com/account/test/key").with(
          :headers => {
            'X-Auth-Token'=>'token'
          }
        ).to_return(
          :status => 200,
          :headers => {'Content-Length' => '12345', 'Content-Type' => 'text/plain'}
        )
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
      context 'successfully calling cloud_request' do
        before(:each) do
          @body = 'The response has this as the body'
          stub_request(:get, "https://the-cloud.com/account/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => @body, :headers => {"Content-Length" => @body.bytesize})

          @filepath = File.join(File.dirname(__FILE__), '../tmp', 'cloud_container_test_file')
          FileUtils.mkdir_p File.dirname @filepath
        end

        it 'should log the fact that it is about to download key' do
          logger.should_receive(:debug).with('downloading key from /account/test')
          cloud_container.download('key', @filepath)
        end

        it 'should write the response body to disk' do
          cloud_container.download('key', @filepath)
          File.open(@filepath, 'r') { |file| file.readline.should eql(@body) }
        end

        it 'should return the number of bytes downloaded' do
          cloud_container.download('key', @filepath).should == 33
        end

        after(:each) do
          File.delete(@filepath) if File.exists?(@filepath)
        end
      end

      context 'unsuccessfully calling cloud_request' do
        before(:each) do
          stub_request(:get, "https://the-cloud.com/account/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 404, :body => "", :headers => {})
        end

        it 'should log the fact that it is about to download key' do
          logger.should_receive(:debug).with('downloading key from /account/test')
          lambda { cloud_container.download('key', @filepath) }.should raise_error
        end
      end
    end

    describe '#list' do
      context 'requesting fewer items than the max per list API call' do
        let(:max) { 1 }

        before(:each) do
          stub_request(:get, "https://the-cloud.com/account/test?limit=1").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(
            :status => 200,
            :body => "The response has this as the body\n",
            :headers => {}
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 of #{max} items from /account/test")
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
          stub_request(:get, "https://the-cloud.com/account/test?limit=10000").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(
            :status => 200,
            :body => "The response has this as the body\n",
            :headers => {}
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 10000 of 100000 items from /account/test")
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
          stub_request(:get, "https://the-cloud.com/account/test?limit=10000").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(
            :status => 200,
            :body => "The response has this as the body\n"*10000,
            :headers => {}
          )
          stub_request(:get, "https://the-cloud.com/account/test?limit=1&marker=The%20response%20has%20this%20as%20the%20body").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(
            :status => 200,
            :body => "The response has this as the body\n",
            :headers => {}
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 10000 of 10001 items from /account/test")
          cloud_container.list(max: max)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_container.list(max: max).length.should eql(10001)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 10000 items; requesting 1 more.")
          cloud_container.list(max: max)
        end
      end

      context 'returns only results with a certain prefix' do
        let(:max) { 1 }
        let(:prefix) { "assets/"}

        before(:each) do
          stub_request(:get, "https://the-cloud.com/account/test?limit=1&prefix=assets/").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "assets/foo.css\n", :headers => {}
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 of 1 items from /account/test")
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
    end

    describe '#search' do
      let(:search_term) { 'foo' }

      context '3 results found' do
        before(:each) do
          stub_request(:get, "https://the-cloud.com/account/test?limit=10000&prefix=foo").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "result\n"*3, :headers => {}
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
          stub_request(:get, "https://the-cloud.com/account/test?limit=10000&prefix=foo").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "", :headers => {}
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
        stub_request(:head, "https://the-cloud.com/account/test").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(
          :status => 200,
          :body => "",
          :headers => {
            'X-Container-Object-Count' => 5,
            'X-Container-Bytes-Used' => 1200
          }
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

    describe '#cdn_metadata' do
      before(:each) do
        stub_request(:head, "https://cdn.the-cloud.com/account/test").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(
          :status => 200,
          :body => "",
          :headers => {
            'X-CDN-Enabled' => 'True',
            'X-CDN-URI' => "http://example.com",
            "X-CDN-STREAMING-URI" => "http://streaming.example.com",
            "X-CDN-SSL-URI" => "https://example.com",
            "X-TTL" => 1234,
            "X-Log-Retention" => "False"
          }
        )
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('retrieving container CDN metadata from /account/test')
        cloud_container.cdn_metadata
      end

      it 'should return a hash containing the number of objects and the total bytes used' do
        cloud_container.cdn_metadata[:cdn_enabled].should    == true
        cloud_container.cdn_metadata[:host].should           == "http://example.com"
        cloud_container.cdn_metadata[:ssl_host].should       == "https://example.com"
        cloud_container.cdn_metadata[:streaming_host].should == "http://streaming.example.com"
        cloud_container.cdn_metadata[:ttl].should            == 1234
        cloud_container.cdn_metadata[:log_retention].should  == false
      end
    end

    describe '#cdn_enable' do
      before(:each) do
        stub_request(:put, "https://cdn.the-cloud.com/account/test").with(
          :headers => {
            'Accept'=>'*/*',
            'X-TTL'=>'60000',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(:status => 201, :body => "")
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('enabling CDN access to /account/test with a cache expiry of 1000 minutes')
        cloud_container.cdn_enable(60000)
      end

      it 'should return true' do
        cloud_container.cdn_enable(60000).should == true
      end
    end
    describe '#expiring_url' do
      it 'should returned a signed URL' do
        url = cloud_container.expiring_url("foo.txt", "secret", 1234567890)
        url.should == "https://the-cloud.com/account/test/foo.txt?temp_url_sig=596355666ef72a9da6b03de32e9dd4ac003ee9be&temp_url_expires=1234567890"
      end
    end
  end
end
