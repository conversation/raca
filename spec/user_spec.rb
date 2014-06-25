require 'spec_helper'

describe Raca::User do

  let!(:account) {
    info = double(Raca::Account)
    allow(info).to receive(:public_endpoint).with("identity").and_return("https://the-cloud.com/identity")
    allow(info).to receive(:auth_token).and_return('token')
    allow(info).to receive(:refresh_cache).and_return(true)
    info
  }
  let!(:http_client) { Raca::HttpClient.new(account, "the-cloud.com") }
  let!(:logger) { double(Object).as_null_object }

  describe '#get' do
    let!(:user) { Raca::User.new(account, "joebloggs") }

    before(:each) do
      allow(account).to receive(:http_client).and_return(http_client)
    end

    context "when the requested username exists" do

      before(:each) do
        expect(http_client).to receive(:get).with("/identity/users?name=joebloggs").and_return(
          instance_double(Net::HTTPSuccess, body: JSON.dump("user" => {username: "joebloggs", email: "joe@example.com"}))
        )
      end

      it 'should return a Hash with the user details' do
        expect(user.details).to eq({"username" => "joebloggs", "email" => "joe@example.com"})
      end
    end

    context "when the requested username doesn't exist" do

      before(:each) do
        expect(http_client).to receive(:get).with("/identity/users?name=joebloggs").and_raise(Raca::NotFoundError)
      end

      it 'should raise a NotFound exception' do
        expect {
          user.details
        }.to raise_error(Raca::NotFoundError)
      end
    end
  end

end
