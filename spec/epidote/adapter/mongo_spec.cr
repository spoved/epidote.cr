require "../../spec_helper"

class Epidote::Adapter::Mongo
  def self._client
    client
  end

  def self._client_ro
    client_ro
  end
end

describe Epidote::Adapter::Mongo do
  adapter = Epidote::Adapter::Mongo

  describe "#client" do
    it "initializes" do
      adapter._client.should be_a ::Mongo::Client
    end
  end

  it "#client_ro" do
    ENV["MONGODB_RO_HOST"]?.should be_nil
    adapter._client_ro.should be adapter._client
  end

  it "#client_name" do
    adapter.client_name.should eq Epidote::Adapter::Mongo::MONGODB_DB_NAME
  end

  it "#has_collection?" do
    MyModel::Mongo.drop
    adapter._client[adapter.database_name].has_collection?("my_model").should be_false
    MyModel::Mongo.init_collection!
    adapter._client[adapter.database_name].has_collection?("my_model").should be_true
  end
end
