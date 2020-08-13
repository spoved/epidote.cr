require "../../spec_helper"
require "uuid"

Spec.before_each do
  begin
    MyModel::MySQL.truncate
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

describe Epidote::Model::MySQL do
  describe "static methods" do
    it "#collection_name" do
      MyModel::MySQL.table_name.should eq "my_model"
    end
  end

  it "#to_json" do
    model = MyModel::MySQL.new(
      id: 100,
      name: "my_name",
      unique_name: "model1"
    )
    model.to_json.should eq %|{"id":100,"name":"my_name","unique_name":"model1","default_value":"a string"}|
  end

  it "#to_hash" do
    model = MyModel::MySQL.new(
      id: 100,
      name: "my_name",
      unique_name: "model1",
      not_nil_value: 5,
    )
    hash = model.to_h
    hash[:id].should eq 100
    hash[:name].should eq "my_name"
    hash[:unique_name].should eq "model1"
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
      model = MyModel::MySQL.new(name: "my_name", unique_name: uuid, not_nil_value: 1)
      other = MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::MySQL.new(id: model.id, name: "my_name", unique_name: uuid, not_nil_value: 1)

      model.should_not eq other
      model.should eq same_other
    end

    it "#===" do
      uuid = UUID.random.to_s
      model = MyModel::MySQL.new(name: "my_name", unique_name: uuid, not_nil_value: 1)
      other = MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::MySQL.new(id: model.id, name: "my_name", unique_name: uuid, not_nil_value: 1)
      alias_other = model

      model.should be alias_other
      model.should_not be other
      model.should_not be same_other
    end
  end

  describe "attributes" do
    it "can be accessed" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      model.name.should eq "my_name"
      model.unique_name.should eq "model1"
      model.default_value.should eq "a string"
    end

    it "can be changed" do
      model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
      model.name = "new_name"
      model.name.should eq "new_name"

      model.unique_name = "model2"
      model.unique_name.should eq "model2"

      model.default_value = "new string"
      model.default_value.should eq "new string"

      new_id = 200
      model.id = new_id
      model.id.should_not be_nil
      model.id.should be_a Int32
      model.id.should eq new_id
    end

    describe "that should be not nil" do
      it "raises exception" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        expect_raises NilAssertionError do
          model.not_nil_value
        end
      end
    end

    describe "#set" do
      it "can be changed" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        model.set :unique_name, "model2"
        model.unique_name.should eq "model2"

        model.set :default_value, "new string"
        model.default_value.should eq "new string"

        new_id = 200
        model.set :id, new_id
        model.id.should_not be_nil
        model.id.should be_a Int32
        model.id.should eq new_id
      end

      it "raises error on missing attribute" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        expect_raises Epidote::Error::UnknownAttribute do
          model.set :not_an_attribute, "value"
        end
      end

      it "raises error on invalid value" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        expect_raises Epidote::Error, "Attribute not_nil_value must be type Int32 not Nil" do
          model.set :not_nil_value, nil
        end
      end
    end

    describe "#get" do
      it "can be accessed" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        model.get(:name).should eq "my_name"
        model.get(:unique_name).should eq "model1"
        model.get(:default_value).should eq "a string"
      end

      it "raises error on missing attribute" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: "model1")
        expect_raises Epidote::Error::UnknownAttribute do
          model.get :not_an_attribute
        end
      end
    end

    describe "when changed" do
      it "changes #dirty?" do
        model = valid_mysql_model.save!
        model.dirty?.should be_false

        model.name = "new_name"
        model.name.should eq "new_name"
        model.dirty?.should be_true
      end

      describe "to a invalid value" do
        pending "raises error on invalid value" do
          # model = MyModel::MySQL.new(name: "my_name", unique_name: "model1", not_nil_value: 1)
        end
      end
    end
  end

  describe "with database" do
    describe "with pre-existing record" do
      it "#saved?" do
        valid_mysql_model.save!.saved?.should be_true
      end

      it "#dirty?" do
        valid_mysql_model.save!.dirty?.should be_false
      end

      it "#all" do
        valid_mysql_model.save!
        MyModel::MySQL.all.size.should eq 1
      end

      it "#each" do
        model = valid_mysql_model.save!
        count = 0
        MyModel::MySQL.each do |m|
          m.should eq model
          count += 1
        end
        count.should eq 1
      end

      it "#find" do
        model = valid_mysql_model.save!
        MyModel::MySQL.find(model.id).should eq model
      end

      it "#query" do
        model = valid_mysql_model.save!
        uuid = model.unique_name

        results = MyModel::MySQL.query(unique_name: uuid)
        results.should_not be_nil
        results.should contain model
        results.size.should eq 1
      end

      describe "with valid attributes" do
        describe "#save" do
          it "does not raise error" do
            model = valid_mysql_model.save!
            model.save
          end

          it "does not update record" do
            model = valid_mysql_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.save

            f_model = MyModel::MySQL.find(model.id).not_nil!
            f_model.id.to_s.should eq model.id.to_s

            f_model.name.should_not eq model.name
            f_model.name.should eq orig_name
          end

          it "does not change #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            model.save
            model.saved?.should be_true
          end
        end

        describe "#save!" do
          it "raises ExistingRecord error" do
            model = valid_mysql_model.save!
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
          end

          it "does not change record" do
            model = valid_mysql_model.save!
            orig_name = model.name
            model.name = "new_name"
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
            f_model = MyModel::MySQL.find(model.id).not_nil!
            f_model.id.to_s.should eq model.id.to_s

            f_model.name.should_not eq model.name
            f_model.name.should eq orig_name
          end

          it "does not change #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
            model.saved?.should be_true
          end
        end

        describe "#update" do
          it "changes record" do
            model = valid_mysql_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.update

            f_model = MyModel::MySQL.find(model.id).not_nil!
            f_model.id.to_s.should eq model.id.to_s

            f_model.name.should eq model.name
            f_model.name.should_not eq orig_name
          end

          it "does not change #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            model.name = "new_name"
            model.update
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_mysql_model.save!
            model.dirty?.should be_false
            model.name = "new_name"
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_false
          end
        end

        describe "#update!" do
          it "changes record" do
            model = valid_mysql_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.update!

            f_model = MyModel::MySQL.find(model.id).not_nil!
            f_model.id.to_s.should eq model.id.to_s

            f_model.name.should eq model.name
            f_model.name.should_not eq orig_name
          end

          it "does not change #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            model.name = "new_name"
            model.update!
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_mysql_model.save!
            model.dirty?.should be_false
            model.name = "new_name"
            model.dirty?.should be_true
            model.update!
            model.dirty?.should be_false
          end
        end

        describe "#destroy" do
          it "removes record" do
            model = valid_mysql_model.save!
            model.destroy
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "changes #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            model.destroy
            model.saved?.should be_false
          end

          it "changes #dirty?" do
            model = valid_mysql_model.save!
            model.dirty?.should be_false
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "removes record" do
            model = valid_mysql_model.save!
            model.destroy!
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "changes #saved?" do
            model = valid_mysql_model.save!
            model.saved?.should be_true
            model.destroy!
            model.saved?.should be_false
          end

          it "changes #dirty?" do
            model = valid_mysql_model.save!
            model.dirty?.should be_false
            model.destroy!
            model.dirty?.should be_true
          end
        end
      end
    end

    describe "without pre-existing record" do
      describe "#first" do
        it "returns nil" do
          MyModel::MySQL.first.should be_nil
        end
      end

      it "#saved?" do
        valid_mysql_model.saved?.should be_false
      end

      it "#dirty?" do
        valid_mysql_model.dirty?.should be_true
      end

      it "#all" do
        MyModel::MySQL.all.should be_empty
      end

      it "#each" do
        called = 0
        MyModel::MySQL.each do |_|
          called += 1
        end
        called.should eq 0
      end

      it "#find" do
        model = MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
        MyModel::MySQL.find(model.id).should be_nil
      end

      it "#query" do
        results = MyModel::MySQL.query(unique_name: UUID.random.to_s)
        results.should_not be_nil
        results.should be_empty
      end

      describe "with valid attributes" do
        describe "#save" do
          it "creates new record" do
            model = valid_mysql_model.save
            MyModel::MySQL.find(model.id).should eq model
          end

          it "changes #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            model.save
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            model.save
            model.dirty?.should be_false
          end
        end

        describe "#save!" do
          it "creates new record" do
            model = valid_mysql_model.save!
            MyModel::MySQL.find(model.id).should eq model
          end

          it "changes #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            model.save!
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            model.save!
            model.dirty?.should be_false
          end
        end

        describe "#update" do
          it "does not raise error" do
            valid_mysql_model.update
          end

          it "does not create record" do
            model = valid_mysql_model.update
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            model.update
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_true
          end
        end

        describe "#update!" do
          it "raises MissingRecord error" do
            model = valid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
          end

          it "does not create record" do
            model = valid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.dirty?.should be_true
          end
        end

        describe "#destroy" do
          it "does not raise error" do
            valid_mysql_model.destroy
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            model.destroy
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "raises MissingRecord error" do
            model = valid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.dirty?.should be_true
          end
        end
      end

      describe "with invalid attributes" do
        describe "#save" do
          it "does not raise error" do
            model = invalid_mysql_model
            model.save
          end

          it "does not create record" do
            model = invalid_mysql_model
            model.save
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_mysql_model
            model.saved?.should_not be_true
            model.save
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_mysql_model
            model.dirty?.should be_true
            model.save
            model.dirty?.should be_true
          end
        end

        describe "#save!" do
          it "raises ValidateFailed error" do
            model = invalid_mysql_model
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
          end

          it "does not create record" do
            model = invalid_mysql_model
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_mysql_model
            model.saved?.should_not be_true
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_mysql_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            model.dirty?.should be_true
          end
        end

        describe "#update" do
          it "does not raise error" do
            model = invalid_mysql_model
            model.update
          end

          it "does not create record" do
            model = invalid_mysql_model
            model.update
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_mysql_model
            model.saved?.should_not be_true
            model.update
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_mysql_model
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_true
          end
        end

        describe "#update!" do
          it "raises MissingRecord error" do
            model = invalid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
          end

          it "does not create record" do
            model = invalid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            MyModel::MySQL.find(model.id).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_mysql_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = invalid_mysql_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.dirty?.should be_true
          end
        end

        describe "#destroy" do
          it "does not raise error" do
            valid_mysql_model.destroy
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            model.destroy
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "raises MissingRecord error" do
            model = valid_mysql_model
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
          end

          it "does not change #saved?" do
            model = valid_mysql_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_mysql_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.dirty?.should be_true
          end
        end
      end
    end

    describe "with multiple pre-existing records" do
      describe "#first" do
        it "returns first record" do
          items = Array(MyModel::MySQL).new
          5.times do
            items << MyModel::MySQL.new(name: "query_me", unique_name: UUID.random.to_s, not_nil_value: 12).save!
          end

          MyModel::MySQL.first.should eq items.first
        end
      end

      describe "#query" do
        it "with matching attributes" do
          items = Array(MyModel::MySQL).new
          5.times do
            items << MyModel::MySQL.new(name: "query_me", unique_name: UUID.random.to_s, not_nil_value: 12).save!
          end

          results = MyModel::MySQL.query(name: "query_me", not_nil_value: 12)
          results.should_not be_nil
          results.size.should eq 5
          items.each do |r|
            results.should contain r
          end
        end

        pending "with partial matching attributes" do
        end

        pending "with no matching attributes" do
        end
      end

      it "#all" do
        MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.all.size.should eq 2
      end

      it "#size" do
        MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.size.should eq 2
      end

      it "#each" do
        MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!

        called = 0
        MyModel::MySQL.each do |r|
          r.should be_a MyModel::MySQL
          called += 1
        end
        called.should be > 0
      end

      it "limits and offsets" do
        MyModel::MySQL.new(name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.new(name: "my_other_name", unique_name: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::MySQL.all(limit: 1).size.should eq 1

        res = MyModel::MySQL.all(limit: 1)
        res.size.should eq 1
        res.first.name.should eq "my_name"

        res = MyModel::MySQL.all(limit: 1, offset: 1)
        res.size.should eq 1
        res.first.name.should eq "my_other_name"
      end
    end
  end
end
