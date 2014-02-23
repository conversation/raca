require 'spec_helper'

describe Raca::Containers do

  let!(:account) {
    info = double(Raca::Account)
    info.stub(:public_endpoint).with("cloudFiles", :ord).and_return("https://the-cloud.com/account")
    info.stub(:auth_token).and_return('token')
    info.stub(:refresh_cache).and_return(true)
    info
  }
  let!(:logger) { double(Object).as_null_object }
  let!(:containers) { Raca::Containers.new(account, :ord) }

  describe '#get' do
    it 'should return a new Raca::Container' do
      Raca::Container.should_receive(:new).with(account, :ord, "container_name")
      containers.get("container_name")
    end
  end

  describe '#containers_metadata' do
    before(:each) do
      stub_request(:head, "https://the-cloud.com/account").with(
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
      logger.should_receieve(:debug).with('retrieving containers metadata from /account/test')
      containers.metadata
    end

    it 'should return a hash of results' do
      containers.metadata.should == {
        containers: 5,
        objects: 10,
        bytes: 1024,
      }
    end
  end

  describe '#set_temp_url_key' do
    before(:each) do
      stub_request(:post, "https://the-cloud.com/account").with(
        :headers => {
          'Accept'=>'*/*',
          'X-Account-Meta-Temp-Url-Key'=>'secret',
          'User-Agent'=>'Ruby',
          'X-Auth-Token'=>'token'
        }
      ).to_return(:status => 201, :body => "")
    end

    it 'should log what it indends to do' do
      logger.should_receieve(:debug).with('setting Account Temp URL Key on /account/test')
      containers.set_temp_url_key("secret")
    end
  end

end
