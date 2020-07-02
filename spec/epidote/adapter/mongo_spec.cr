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

  it "#has_collection?" do
    MyModel::Mongo.drop
    adapter.client[adapter.database_name].has_collection?("my_model").should be_false
    MyModel::Mongo.init_collection!
    adapter.client[adapter.database_name].has_collection?("my_model").should be_true
  end
end
