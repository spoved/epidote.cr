require "../../spec_helper"

describe Epidote::Adapter::Mongo do
  adapter = Epidote::Adapter::Mongo
  describe "#client" do
    it "initializes" do
      adapter.client.should be_a ::Mongo::Client
    end
  end

  it "#client_ro" do
    ENV["MONGODB_RO_HOST"]?.should be_nil
    adapter.client_ro.should be adapter.client
  end

  it "#client_name" do
    adapter.client_name.should eq Epidote::Adapter::Mongo::MONGODB_DB_NAME
  end

  # it "#with_database" do
  #   adapter.with_database do |db|
  #     db.should be_a ::Mongo::Database
  #   end
  # end
end
