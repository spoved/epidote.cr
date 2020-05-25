require "../../spec_helper"
require "uuid"
describe Epidote::Model::Mongo do
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

  it "#to_hash" do
    model = MyModel::Mongo.new(
      id: BSON::ObjectId.new("5ebb05cd1761ee7ef4165742"),
      name: "my_name",
      unique_name: "model1",
      not_nil_value: 5,
    )
    hash = model.to_h
    hash[:id].should eq BSON::ObjectId.new("5ebb05cd1761ee7ef4165742")
    hash[:name].should eq "my_name"
    hash[:unique_name].should eq "model1"
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

  describe "can be compared" do
    it "#==" do
      uuid = UUID.random.to_s
      model = MyModel::Mongo.new(name: "my_name", unique_name: uuid, not_nil_value: 1)
      other = MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::Mongo.new(id: model.id, name: "my_name", unique_name: uuid, not_nil_value: 1)

      model.should_not eq other
      model.should eq same_other
    end

    it "#===" do
      uuid = UUID.random.to_s
      model = MyModel::Mongo.new(name: "my_name", unique_name: uuid, not_nil_value: 1)
      other = MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::Mongo.new(id: model.id, name: "my_name", unique_name: uuid, not_nil_value: 1)
      alias_other = model

      model.should be alias_other
      model.should_not be other
      model.should_not be same_other
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
        MyModel::Mongo.all.should be_empty
        MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Mongo.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Mongo.all.size.should eq 2
      end

      it "#each" do
        MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Mongo.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!

        called = 0
        MyModel::Mongo.each do |r|
          r.should be_a MyModel::Mongo
          called += 1
        end
        called.should be > 0
      end

      describe "existing record" do
        it "#find" do
          model = MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
          MyModel::Mongo.find(model.id).should eq model
        end

        it "#query" do
          uuid = UUID.random.to_s
          model = MyModel::Mongo.new(name: "my_name", unique_name: uuid, not_nil_value: 1).save!

          results = MyModel::Mongo.query(unique_name: uuid)
          results.should_not be_nil
          results.should contain model
          results.size.should eq 1
        end
      end

      describe "multiple records" do
        it "#query" do
          items = Array(MyModel::Mongo).new
          5.times do
            items << MyModel::Mongo.new(name: "query_me", unique_name: UUID.random.to_s, not_nil_value: 12).save!
          end

          results = MyModel::Mongo.query(name: "query_me", not_nil_value: 12)
          results.should_not be_nil
          results.size.should eq 5
          items.each do |r|
            results.should contain r
          end
        end
      end

      describe "non-existing record" do
        it "#find" do
          model = MyModel::Mongo.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
          MyModel::Mongo.find(model.id).should be_nil
        end

        it "#query" do
          results = MyModel::Mongo.query(unique_name: UUID.random.to_s)
          results.should_not be_nil
          results.should be_empty
        end
      end
    end

    describe "create" do
      describe "#save" do
        it "does not raise error" do
          model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s)
          model.valid?.should be_false
          model.save
        end

        it "does not save model" do
          model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s)
          model.valid?.should be_false
          model.save
          MyModel::Mongo.find(model.id).should be_nil
        end
      end

      describe "#save!" do
        it "raises error" do
          model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s)
          model.valid?.should be_false
          expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
            model.save!
          end
        end

        it "does not save model" do
          model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s)
          model.valid?.should be_false
          expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
            model.save!
          end
          MyModel::Mongo.find(model.id).should be_nil
        end
      end
    end
  end
end
