require "../../spec_helper"

describe MyModel::MySQL do
  describe "static methods" do
    it "#table_name" do
      MyModel::MySQL.table_name.should eq "my_model"
    end
  end

  it "#to_json" do
    model = MyModel::MySQL.new(
      id: 5,
      name: "my_name",
      unique_name: "model1"
    )
    model.to_json.should eq %|{"id":5,"name":"my_name","unique_name":"model1","default_value":"a string"}|
  end

  describe "can be validated" do
    it "#valid?" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      model.valid?.should be_false
      model.not_nil_value = 5
      model.valid?.should be_true
      model.not_nil_value.should eq 5
    end

    it "#valid!" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      expect_raises Exception do
        model.valid!
      end

      model.not_nil_value = 5
      model.valid!
      model.not_nil_value.should eq 5
    end
  end

  describe "attributes" do
    it "can be accessed" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      model.name.should eq "my_name"
      model.unique_name.should eq "model1"
      model.default_value.should eq "a string"
      model.id.should be_nil
    end

    it "can be changed" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      model.name = "new_name"
      model.name.should eq "new_name"

      model.unique_name = "model2"
      model.unique_name.should eq "model2"

      model.default_value = "new string"
      model.default_value.should eq "new string"

      new_id = 5
      model.id = new_id
      model.id.should_not be_nil
      model.id.should be_a Int32
      model.id.should eq new_id
    end

    describe "that should be not nil" do
      it "raises exception" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        expect_raises Exception do
          model.not_nil_value
        end
      end
    end
  end
end
