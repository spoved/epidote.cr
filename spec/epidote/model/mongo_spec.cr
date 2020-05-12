require "../../spec_helper"

describe MyModel::Mongo do
  describe "static methods" do
    it "#collection_name" do
      MyModel::Mongo.collection_name.should eq "my_model"
    end
  end

  it "#to_json" do
    model = MyModel::Mongo.new(
      id: BSON::ObjectId.new("5ebb05cd1761ee7ef4165742"),
      name: "my_name",
      unique_name: "model1"
    )
    model.to_json.should eq %|{"_id":"5ebb05cd1761ee7ef4165742","name":"my_name","unique_name":"model1","default_value":"a string"}|
  end

  describe "attributes" do
    it "can be accessed" do
      model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
      model.name.should eq "my_name"
      model.unique_name.should eq "model1"
      model.default_value.should eq "a string"
      model.id.should_not be_nil
      model.id.should be_a BSON::ObjectId
    end

    it "can be changed" do
      model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
      model.name = "new_name"
      model.name.should eq "new_name"

      model.unique_name = "model2"
      model.unique_name.should eq "model2"

      model.default_value = "new string"
      model.default_value.should eq "new string"

      new_id = BSON::ObjectId.new
      model.id = new_id
      model.id.should_not be_nil
      model.id.should be_a BSON::ObjectId
      model.id.should eq new_id
    end
  end
end
