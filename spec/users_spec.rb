require 'spec_helper'

describe Raca::Users do

  let!(:account) {
    info = double(Raca::Account)
    allow(info).to receive(:public_endpoint).with("identity").and_return("https://the-cloud.com/identity")
    allow(info).to receive(:auth_token).and_return('token')
    allow(info).to receive(:refresh_cache).and_return(true)
    info
  }
  let!(:http_client) { Raca::HttpClient.new(account, "the-cloud.com") }
  let!(:logger) { double(Object).as_null_object }
  let!(:users) { Raca::Users.new(account) }

  describe '#get' do

    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).with("/identity/users").and_return(
        instance_double(Net::HTTPSuccess, body: JSON.dump("users" => [{"username" => "joebloggs"}]))
      )
    end

    context "when the requested username exists" do
      it 'should return a new Raca::User with the correct username' do
        user = users.get("joebloggs")
        expect(user).to be_a Raca::User
        expect(user.username).to eq "joebloggs"
      end
    end

    context "when the requested username doesn't exist" do
      it 'should return nil' do
        user = users.get("someguy")
        expect(user).to be_nil
      end
    end
  end

end
