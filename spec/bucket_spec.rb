require 'spec_helper'

describe Raca::Bucket do

  describe "MAX_ITEMS_PER_LIST" do
    subject { Raca::Bucket::MAX_ITEMS_PER_LIST }
    it { should eql(10_000) }
  end

  describe '#initialization' do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:storage_host).and_return("the_cloud.com")
      info.stub(:cdn_host).and_return("cdn.the_cloud.com")
      info.stub(:path).and_return("/bucket_path")
      info.stub(:auth_token).and_return('token')
      info.stub(:refresh_cache).and_return(true)
      info
    }

    it 'should raise an argument error if the supplied bucket name contains a "/"' do
      lambda { Raca::Bucket.new(account, 'a_broken_bucket_name/') }.should raise_error(ArgumentError)
    end

    it 'should set the bucket_name atttribute' do
      bucket = 'mah_buckit'
      Raca::Bucket.new(account, bucket).bucket_name.should eql(bucket)
    end

  end

  # This spec could be written for any public method on Raca::Bucket. The point
  # is to test the automatic retry after receiving a 401 response, not to test the
  # metadata method itself
  describe "metadata request with stale auth details" do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:storage_host).and_return("the_cloud.com")
      info.stub(:cdn_host).and_return("cdn.the_cloud.com")
      info.stub(:path).and_return("/bucket_path")
      info.stub(:auth_token).and_return('stale_token','fresh_token')
      info.stub(:refresh_cache).and_return(true)
      info
    }
    let!(:cloud_bucket) { Raca::Bucket.new(account, 'test') }

    before(:each) do
      stub_request(:head, "https://the_cloud.com/bucket_path/test").with(
        :headers => {'X-Auth-Token'=>'stale_token'}
      ).to_return(:status => 401, :body => "")
      stub_request(:head, "https://the_cloud.com/bucket_path/test").with(
        :headers => {'X-Auth-Token'=>'fresh_token'}
      ).to_return(
        :status => 200,
        :headers => {'X-Container-Object-Count' => 5, 'X-Container-Bytes-Used' => 1200}
      )
    end

    it "should automatically re-auth and try again" do
      cloud_bucket.metadata.should eql({:objects => 5, :bytes => 1200})
    end
  end

  describe 'instance method: ' do
    let!(:account) {
      info = double(Raca::Account)
      info.stub(:storage_host).and_return("the_cloud.com")
      info.stub(:cdn_host).and_return("cdn.the_cloud.com")
      info.stub(:path).and_return("/bucket_path")
      info.stub(:auth_token).and_return('token')
      info.stub(:refresh_cache).and_return(true)
      info
    }
    let!(:logger) { double(Object).as_null_object }
    let!(:cloud_bucket) { Raca::Bucket.new(account, 'test', logger: logger) }

    describe '#upload' do
      context 'with a StringIO object' do
        let(:data_or_path) { StringIO.new('some string', 'r') }

        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key").with(
            :body => "some string",
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'11',
              'Content-Type'=>'application/octet-stream',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {})
        end

        it "should call upload_io" do
          cloud_bucket.upload('key', data_or_path).is_a?(Net::HTTPSuccess).should be_true
        end
      end

      context 'with a File object' do
        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'0',
              'Content-Type'=>'text/plain',
              'Etag'=>'d41d8cd98f00b204e9800998ecf8427e',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {})
        end

        it "should call upload_io" do
          File.open(File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt'), 'r') do |data_or_path|
            cloud_bucket.upload('key', data_or_path).is_a?(Net::HTTPSuccess).should be_true
          end
        end
      end

      context 'with a String object' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'Content-Length'=>'0',
              'Content-Type'=>'text/plain',
              'Etag'=>'d41d8cd98f00b204e9800998ecf8427e',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {})
        end

        it "should call upload_io" do
          cloud_bucket.upload('key', data_or_path).is_a?(Net::HTTPSuccess).should be_true
        end
      end

      context 'with a String object that exceeds than the large file threshold' do
        let(:data_or_path) { StringIO.new("abcdefg") }

        before do
          stub_const("Raca::Bucket::LARGE_FILE_THRESHOLD", 3)
          stub_const("Raca::Bucket::LARGE_FILE_SEGMENT_SIZE", 3)
        end

        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key.000").with(
            :headers => {
              'Content-Length'=>'3',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "1" })
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key.001").with(
            :headers => {
              'Content-Length'=>'3',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "2" })
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key.002").with(
            :headers => {
              'Content-Length'=>'1',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {ETag: "3" })
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key?multipart-manifest=put").with(
            :body => %Q{[{"path":"test/key.000","etag":"1","size_bytes":3},{"path":"test/key.001","etag":"2","size_bytes":3},{"path":"test/key.002","etag":"3","size_bytes":1}]},
            :headers => {
              'Content-Length'=>'151',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => "", :headers => {})
        end

        it "should call upload_io" do
          cloud_bucket.upload('key', data_or_path).is_a?(Net::HTTPSuccess).should be_true
        end
      end

      context 'with a String object when Rackspace times out' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_raise(Timeout::Error, Timeout::Error).then.to_return(
            :status => 200, :body => "", :headers => {}
          )
        end

        it "should make the correct HTTP calls" do
          cloud_bucket.upload('key', data_or_path).is_a?(Net::HTTPSuccess).should be_true
        end
      end

      context 'with a String object when Rackspace times out four times' do
        let(:data_or_path) { File.join(File.dirname(__FILE__), 'fixtures', 'bogus.txt') }

        before(:each) do
          stub_request(:put, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {'X-Auth-Token'=>'token'}
          ).to_raise(Timeout::Error, Timeout::Error, Timeout::Error, Timeout::Error)
        end

        it "should raise a descriptive execption" do
          lambda {
            cloud_bucket.upload('key', data_or_path)
          }.should raise_error(RuntimeError)
        end
      end

      context 'with another type of object' do
        let(:data_or_path) { 4 }

        it 'should raise an argument error' do
          lambda { cloud_bucket.upload('key', data_or_path) }.should raise_error(ArgumentError)
        end
      end
    end

    describe '#delete' do
      before(:each) do
        stub_request(:delete, "https://the_cloud.com/bucket_path/test/key").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(:status => 200, :body => "", :headers => {})
      end

      it 'should log the fact that it deleted the key' do
        logger.should_receive(:debug).with('deleting key from /bucket_path/test')
        cloud_bucket.delete('key')
      end
    end

    describe '#purge_from_akamai' do
      before(:each) do
        stub_request(:delete, "https://cdn.the_cloud.com/bucket_path/test/key").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token',
            'X-Purge-Email' => 'services@theconversation.edu.au'
          }
        ).to_return(:status => 200, :body => "", :headers => {})
      end

      it 'should log the fact that it deleted the key' do
        logger.should_receive(:debug).with('Requesting /bucket_path/test/key to be purged from the CDN')
        cloud_bucket.purge_from_akamai('key', 'services@theconversation.edu.au')
      end
    end

    describe '#download' do
      context 'successfully calling cloud_request' do
        before(:each) do
          @body = 'The response has this as the body'
          stub_request(:get, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 200, :body => @body, :headers => {})

          @filepath = File.join(File.dirname(__FILE__), '../tmp', 'cloud_bucket_test_file')
          FileUtils.mkdir_p File.dirname @filepath
        end

        it 'should log the fact that it is about to download key' do
          logger.should_receive(:debug).with('downloading key from /bucket_path/test')
          cloud_bucket.download('key', @filepath)
        end

        it 'should write the response body to disk' do
          cloud_bucket.download('key', @filepath)
          File.open(@filepath, 'r') { |file| file.readline.should eql(@body) }
        end

        after(:each) do
          File.delete(@filepath) if File.exists?(@filepath)
        end
      end

      context 'unsuccessfully calling cloud_request' do
        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test/key").with(
            :headers => {
              'Accept'=>'*/*',
              'User-Agent'=>'Ruby',
              'X-Auth-Token'=>'token'
            }
          ).to_return(:status => 404, :body => "", :headers => {})
        end

        it 'should log the fact that it is about to download key' do
          logger.should_receive(:debug).with('downloading key from /bucket_path/test')
          lambda { cloud_bucket.download('key', @filepath) }.should raise_error
        end
      end
    end

    describe '#list' do
      context 'requesting fewer items than the max per list API call' do
        let(:max) { 1 }

        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=1").with(
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
          logger.should_receive(:debug).with("retrieving up to 1 of #{max} items from /bucket_path/test")
          cloud_bucket.list(max: max)
        end

        it 'should be an array of length requested' do
          cloud_bucket.list(max: max).length.should eql(max)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; we don't need any more.")
          cloud_bucket.list(max: max)
        end
      end

      context 'returns fewer results than the maximum asked for' do
        let(:max) { 100000 }

        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=10000").with(
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
          logger.should_receive(:debug).with("retrieving up to 10000 of 100000 items from /bucket_path/test")
          cloud_bucket.list(max: max)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_bucket.list(max: max).length.should eql(1)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; there can't be any more.")
          cloud_bucket.list(max: max)
        end
      end

      context 'returns fewer items than requested and recursively requests more' do
        let(:max) { 10001 }

        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=10000").with(
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
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=1&marker=The%20response%20has%20this%20as%20the%20body").with(
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
          logger.should_receive(:debug).with("retrieving up to 10000 of 10001 items from /bucket_path/test")
          cloud_bucket.list(max: max)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_bucket.list(max: max).length.should eql(10001)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 10000 items; requesting 1 more.")
          cloud_bucket.list(max: max)
        end
      end

      context 'returns only results with a certain prefix' do
        let(:max) { 1 }
        let(:prefix) { "assets/"}

        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=1&prefix=assets/").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "assets/foo.css\n", :headers => {}
          )
        end

        it 'should log what it intends to do' do
          logger.should_receive(:debug).with("retrieving up to 1 of 1 items from /bucket_path/test")
          cloud_bucket.list(max: max, prefix: prefix)
        end

        it 'should be an array of length found by cloud_request' do
          cloud_bucket.list(max: max, prefix: prefix).length.should eql(1)
        end

        it 'should log what it has done when complete' do
          logger.should_receive(:debug).with("Got 1 items; we don't need any more.")
          cloud_bucket.list(max: max, prefix: prefix)
        end
      end
    end

    describe '#search' do
      let(:search_term) { 'foo' }

      context '3 results found' do
        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=10000&prefix=foo").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "result\n"*3, :headers => {}
          )
        end

        it 'should log what it indends to do' do
          logger.should_receive(:debug).with("retrieving bucket listing from /bucket_path/test items starting with #{search_term}")
          cloud_bucket.search(search_term)
        end

        it 'should return an array of search results' do
          cloud_bucket.search(search_term).length.should eql(3)
        end
      end

      context 'no results found' do
        before(:each) do
          stub_request(:get, "https://the_cloud.com/bucket_path/test?limit=10000&prefix=foo").with(
            :headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby', 'X-Auth-Token'=>'token'}
          ).to_return(
            :status => 200, :body => "", :headers => {}
          )
        end

        it 'should log what it indends to do' do
          logger.should_receive(:debug).with("retrieving bucket listing from /bucket_path/test items starting with #{search_term}")
          cloud_bucket.search(search_term)
        end

        it 'should return an empty array of search results' do
          cloud_bucket.search(search_term).should eql([])
        end
      end
    end

    describe '#metadata' do
      before(:each) do
        stub_request(:head, "https://the_cloud.com/bucket_path/test").with(
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
        logger.should_receieve(:debug).with('retrieving bucket metadata from /bucket_path/test')
        cloud_bucket.metadata
      end

      it 'should return a hash containing the number of objects and the total bytes used' do
        cloud_bucket.metadata.should eql({:objects => 5, :bytes => 1200})
      end
    end

    describe '#cdn_metadata' do
      before(:each) do
        stub_request(:head, "https://cdn.the_cloud.com/bucket_path/test").with(
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
        logger.should_receieve(:debug).with('retrieving bucket CDN metadata from /bucket_path/test')
        cloud_bucket.cdn_metadata
      end

      it 'should return a hash containing the number of objects and the total bytes used' do
        cloud_bucket.cdn_metadata[:cdn_enabled].should    == true
        cloud_bucket.cdn_metadata[:host].should           == "http://example.com"
        cloud_bucket.cdn_metadata[:ssl_host].should       == "https://example.com"
        cloud_bucket.cdn_metadata[:streaming_host].should == "http://streaming.example.com"
        cloud_bucket.cdn_metadata[:ttl].should            == 1234
        cloud_bucket.cdn_metadata[:log_retention].should  == false
      end
    end
    describe '#containers_metadata' do
      before(:each) do
        stub_request(:head, "https://the_cloud.com/bucket_path").with(
          :headers => {
            'Accept'=>'*/*',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(
          :status => 201,
          :body => "",
          :headers => {
            'X-Account-Container-Count'=>'5',
            'X-Account-Object-Count'=>'10',
            'X-Account-Bytes-Used'=>'1024',
          }
        )
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('retrieving containers metadata from /bucket_path/test')
        cloud_bucket.containers_metadata
      end

      it 'should return a hash of results' do
        cloud_bucket.containers_metadata.should == {
          containers: 5,
          objects: 10,
          bytes: 1024,
        }
      end
    end

    describe '#cdn_enable' do
      before(:each) do
        stub_request(:put, "https://cdn.the_cloud.com/bucket_path/test").with(
          :headers => {
            'Accept'=>'*/*',
            'X-TTL'=>'60000',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(:status => 201, :body => "")
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('enabling CDN access to /bucket_path/test with a cache expiry of 1000 minutes')
        cloud_bucket.cdn_enable(60000)
      end
    end
    describe '#set_temp_url_key' do
      before(:each) do
        stub_request(:post, "https://the_cloud.com/bucket_path").with(
          :headers => {
            'Accept'=>'*/*',
            'X-Account-Meta-Temp-Url-Key'=>'secret',
            'User-Agent'=>'Ruby',
            'X-Auth-Token'=>'token'
          }
        ).to_return(:status => 201, :body => "")
      end

      it 'should log what it indends to do' do
        logger.should_receieve(:debug).with('setting Account Temp URL Key on /bucket_path/test')
        cloud_bucket.set_temp_url_key("secret")
      end
    end
    describe '#expiring_url' do
      it 'should returned a signed URL' do
        url = cloud_bucket.expiring_url("foo.txt", "secret", 1234567890)
        url.should == "https://the_cloud.com/bucket_path/test/foo.txt?temp_url_sig=d71fda98474a8ea5ed6eb84fa50cf868f8759db3&temp_url_expires=1234567890"
      end
    end
  end
end
