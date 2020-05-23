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

  describe "can be validated" do
    it "#valid?" do
      model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
      model.valid?.should be_false
      model.not_nil_value = 5
      model.valid?.should be_true
      model.not_nil_value.should eq 5
    end

    it "#valid!" do
      model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
      expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
        model.valid!
      end

      model.not_nil_value = 5
      model.valid!
      model.not_nil_value.should eq 5
    end
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

    describe "that should be not nil" do
      it "raises exception" do
        model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
        expect_raises NilAssertionError do
          model.not_nil_value
        end
      end
    end

    describe "#set" do
      it "can be changed" do
        model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        model.set :unique_name, "model2"
        model.unique_name.should eq "model2"

        model.set :default_value, "new string"
        model.default_value.should eq "new string"

        new_id = BSON::ObjectId.new
        model.set :id, new_id
        model.id.should_not be_nil
        model.id.should be_a BSON::ObjectId
        model.id.should eq new_id
      end

      it "raises error on missing attribute" do
        model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        expect_raises Epidote::Error::UnknownAttribute do
          model.set :not_an_attribute, "value"
        end
      end
    end

    describe "#get" do
      it "can be accessed" do
        model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
        model.get(:name).should eq "my_name"
        model.get(:unique_name).should eq "model1"
        model.get(:default_value).should eq "a string"
        model.get(:id).should_not be_nil
        model.get(:id).should be_a BSON::ObjectId
      end

      it "raises error on missing attribute" do
        model = MyModel::Mongo.new(name: "my_name", unique_name: "model1")
        expect_raises Epidote::Error::UnknownAttribute do
          model.get :not_an_attribute
        end
      end
    end
  end

  describe "with database" do
    describe "query" do
      it "#all" do
        MyModel::Mongo.all
      end
    end
  end
end
