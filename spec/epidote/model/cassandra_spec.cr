require "../../spec_helper"
require "uuid"

Spec.before_each do
  begin
    MyModel::Cassandra.truncate
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

describe Epidote::Model::Cassandra do
  describe "static methods" do
    it "#table_name" do
      MyModel::Cassandra.table_name.should eq "my_model"
    end
  end

  it "#to_json" do
    model = MyModel::Cassandra.new(
      uuid: UUID.new("50554d6e-29bb-11e5-b345-feff819cdc9f"),
      name: "my_name",
      not_nil_value: 43
    )
    model.to_json.should eq %|{"uuid":"50554d6e-29bb-11e5-b345-feff819cdc9f","name":"my_name","default_value":"a string","not_nil_value":43}|
  end

  it "#to_hash" do
    model = MyModel::Cassandra.new(
      uuid: UUID.new("50554d6e-29bb-11e5-b345-feff819cdc9f"),
      name: "my_name",
      default_value: "model1",
      not_nil_value: 5,
    )
    hash = model.to_h
    hash[:uuid].should eq UUID.new("50554d6e-29bb-11e5-b345-feff819cdc9f")
    hash[:name].should eq "my_name"
    hash[:default_value].should eq "model1"
  end

  describe "can be validated" do
    it "#valid?" do
      model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
      model.valid?.should be_false
      model.not_nil_value = 5
      model.valid?.should be_true
      model.not_nil_value.should eq 5
    end

    it "#valid!" do
      model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
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
      model = MyModel::Cassandra.new(name: "my_name", default_value: uuid, not_nil_value: 1)
      other = MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::Cassandra.new(uuid: model.uuid, name: "my_name", default_value: uuid, not_nil_value: 1)

      model.should_not eq other
      model.should eq same_other
    end

    it "#===" do
      uuid = UUID.random.to_s
      model = MyModel::Cassandra.new(name: "my_name", default_value: uuid, not_nil_value: 1)
      other = MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1)
      same_other = MyModel::Cassandra.new(uuid: model.uuid, name: "my_name", default_value: uuid, not_nil_value: 1)
      alias_other = model

      model.should be alias_other
      model.should_not be other
      model.should_not be same_other
    end
  end

  describe "attributes" do
    it "can be accessed" do
      model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
      model.name.should eq "my_name"
      model.default_value.should eq "model1"
    end

    it "can be changed" do
      model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
      model.name = "new_name"
      model.name.should eq "new_name"

      model.default_value = "model2"
      model.default_value.should eq "model2"

      model.default_value = "new string"
      model.default_value.should eq "new string"

      new_id = UUID.random
      model.uuid = new_id
      model.uuid.should_not be_nil
      model.uuid.should be_a UUID
      model.uuid.should eq new_id
    end

    describe "that should be not nil" do
      it "raises exception" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        expect_raises NilAssertionError do
          model.not_nil_value
        end
      end
    end

    describe "#set" do
      it "can be changed" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        model.set :default_value, "model2"
        model.default_value.should eq "model2"

        model.set :default_value, "new string"
        model.default_value.should eq "new string"

        new_id = UUID.random
        model.set :uuid, new_id
        model.uuid.should_not be_nil
        model.uuid.should be_a UUID
        model.uuid.should eq new_id
      end

      it "raises error on missing attribute" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        expect_raises Epidote::Error::UnknownAttribute do
          model.set :not_an_attribute, "value"
        end
      end

      it "raises error on invalid value" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        model.set :name, "new_name"
        model.name.should eq "new_name"

        expect_raises Epidote::Error, "Attribute not_nil_value must be type Int32 not Nil" do
          model.set :not_nil_value, nil
        end
      end
    end

    describe "#get" do
      it "can be accessed" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        model.get(:name).should eq "my_name"
        model.get(:default_value).should eq "model1"
      end

      it "raises error on missing attribute" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: "model1")
        expect_raises Epidote::Error::UnknownAttribute do
          model.get :not_an_attribute
        end
      end
    end

    describe "when changed" do
      it "changes #dirty?" do
        model = valid_cassandra_model.save!
        model.dirty?.should be_false

        model.name = "new_name"
        model.name.should eq "new_name"
        model.dirty?.should be_true
      end

      describe "to a invalid value" do
        pending "raises error on invalid value" do
          # model = MyModel::Cassandra.new(name: "my_name", default_value: "model1", not_nil_value: 1)
        end
      end
    end
  end

  describe "with database" do
    describe "with pre-existing record" do
      it "#saved?" do
        valid_cassandra_model.save!.saved?.should be_true
      end

      it "#dirty?" do
        valid_cassandra_model.save!.dirty?.should be_false
      end

      it "#all" do
        valid_cassandra_model.save!
        MyModel::Cassandra.all.size.should eq 1
      end

      it "#each" do
        model = valid_cassandra_model.save!
        count = 0
        MyModel::Cassandra.each do |m|
          m.should eq model
          count += 1
        end
        count.should eq 1
      end

      it "#find" do
        model = valid_cassandra_model.save!
        MyModel::Cassandra.find(model.uuid).should eq model
      end

      it "#query" do
        model = valid_cassandra_model.save!
        uuid = model.default_value

        results = MyModel::Cassandra.query(default_value: uuid)
        results.should_not be_nil
        results.should contain model
        results.size.should eq 1
      end

      describe "with valid attributes" do
        describe "#save" do
          it "does not raise error" do
            model = valid_cassandra_model.save!
            model.save
          end

          it "does not update record" do
            model = valid_cassandra_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.save

            f_model = MyModel::Cassandra.find(model.uuid).not_nil!
            f_model.uuid.to_s.should eq model.uuid.to_s

            f_model.name.should_not eq model.name
            f_model.name.should eq orig_name
          end

          it "does not change #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            model.save
            model.saved?.should be_true
          end
        end

        describe "#save!" do
          it "raises ExistingRecord error" do
            model = valid_cassandra_model.save!
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
          end

          it "does not change record" do
            model = valid_cassandra_model.save!
            orig_name = model.name
            model.name = "new_name"
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
            f_model = MyModel::Cassandra.find(model.uuid).not_nil!
            f_model.uuid.to_s.should eq model.uuid.to_s

            f_model.name.should_not eq model.name
            f_model.name.should eq orig_name
          end

          it "does not change #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            expect_raises Epidote::Error::ExistingRecord do
              model.save!
            end
            model.saved?.should be_true
          end
        end

        describe "#update" do
          it "changes record" do
            model = valid_cassandra_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.update

            f_model = MyModel::Cassandra.find(model.uuid).not_nil!
            f_model.uuid.to_s.should eq model.uuid.to_s

            f_model.name.should eq model.name
            f_model.name.should_not eq orig_name
          end

          it "does not change #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            model.name = "new_name"
            model.update
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_cassandra_model.save!
            model.dirty?.should be_false
            model.name = "new_name"
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_false
          end
        end

        describe "#update!" do
          it "changes record" do
            model = valid_cassandra_model.save!
            orig_name = model.name
            model.name = "new_name"
            model.update!

            f_model = MyModel::Cassandra.find(model.uuid).not_nil!
            f_model.uuid.to_s.should eq model.uuid.to_s

            f_model.name.should eq model.name
            f_model.name.should_not eq orig_name
          end

          it "does not change #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            model.name = "new_name"
            model.update!
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_cassandra_model.save!
            model.dirty?.should be_false
            model.name = "new_name"
            model.dirty?.should be_true
            model.update!
            model.dirty?.should be_false
          end
        end

        describe "#destroy" do
          it "removes record" do
            model = valid_cassandra_model.save!
            model.destroy
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "changes #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            model.destroy
            model.saved?.should be_false
          end

          it "changes #dirty?" do
            model = valid_cassandra_model.save!
            model.dirty?.should be_false
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "removes record" do
            model = valid_cassandra_model.save!
            model.destroy!
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "changes #saved?" do
            model = valid_cassandra_model.save!
            model.saved?.should be_true
            model.destroy!
            model.saved?.should be_false
          end

          it "changes #dirty?" do
            model = valid_cassandra_model.save!
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
          MyModel::Cassandra.first.should be_nil
        end
      end

      it "#saved?" do
        valid_cassandra_model.saved?.should be_false
      end

      it "#dirty?" do
        valid_cassandra_model.dirty?.should be_true
      end

      it "#all" do
        MyModel::Cassandra.all.should be_empty
      end

      it "#each" do
        called = 0
        MyModel::Cassandra.each do |_|
          called += 1
        end
        called.should eq 0
      end

      it "#find" do
        model = MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1)
        MyModel::Cassandra.find(model.uuid).should be_nil
      end

      it "#query" do
        results = MyModel::Cassandra.query(default_value: UUID.random.to_s)
        results.should_not be_nil
        results.should be_empty
      end

      describe "with valid attributes" do
        describe "#save" do
          it "creates new record" do
            model = valid_cassandra_model.save
            MyModel::Cassandra.find(model.uuid).should eq model
          end

          it "changes #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            model.save
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            model.save
            model.dirty?.should be_false
          end
        end

        describe "#save!" do
          it "creates new record" do
            model = valid_cassandra_model.save!
            MyModel::Cassandra.find(model.uuid).should eq model
          end

          it "changes #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            model.save!
            model.saved?.should be_true
          end

          it "changes #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            model.save!
            model.dirty?.should be_false
          end
        end

        describe "#update" do
          it "does not raise error" do
            valid_cassandra_model.update
          end

          it "does not create record" do
            model = valid_cassandra_model.update
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            model.update
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_true
          end
        end

        describe "#update!" do
          it "raises MissingRecord error" do
            model = valid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
          end

          it "does not create record" do
            model = valid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.dirty?.should be_true
          end
        end

        describe "#destroy" do
          it "does not raise error" do
            valid_cassandra_model.destroy
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            model.destroy
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "raises MissingRecord error" do
            model = valid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
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
            model = invalid_cassandra_model
            model.save
          end

          it "does not create record" do
            model = invalid_cassandra_model
            model.save
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_cassandra_model
            model.saved?.should_not be_true
            model.save
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_cassandra_model
            model.dirty?.should be_true
            model.save
            model.dirty?.should be_true
          end
        end

        describe "#save!" do
          it "raises ValidateFailed error" do
            model = invalid_cassandra_model
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
          end

          it "does not create record" do
            model = invalid_cassandra_model
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_cassandra_model
            model.saved?.should_not be_true
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_cassandra_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::ValidateFailed, "The following attributes cannot be nil: not_nil_value" do
              model.save!
            end
            model.dirty?.should be_true
          end
        end

        describe "#update" do
          it "does not raise error" do
            model = invalid_cassandra_model
            model.update
          end

          it "does not create record" do
            model = invalid_cassandra_model
            model.update
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_cassandra_model
            model.saved?.should_not be_true
            model.update
            model.saved?.should_not be_true
          end

          it "does not change #dirty?" do
            model = invalid_cassandra_model
            model.dirty?.should be_true
            model.update
            model.dirty?.should be_true
          end
        end

        describe "#update!" do
          it "raises MissingRecord error" do
            model = invalid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
          end

          it "does not create record" do
            model = invalid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            MyModel::Cassandra.find(model.uuid).should be_nil
          end

          it "does not change #saved?" do
            model = invalid_cassandra_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = invalid_cassandra_model
            model.dirty?.should be_true
            expect_raises Epidote::Error::MissingRecord do
              model.update!
            end
            model.dirty?.should be_true
          end
        end

        describe "#destroy" do
          it "does not raise error" do
            valid_cassandra_model.destroy
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            model.destroy
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
            model.dirty?.should be_true
            model.destroy
            model.dirty?.should be_true
          end
        end

        describe "#destroy!" do
          it "raises MissingRecord error" do
            model = valid_cassandra_model
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
          end

          it "does not change #saved?" do
            model = valid_cassandra_model
            model.saved?.should be_false
            expect_raises Epidote::Error::MissingRecord do
              model.destroy!
            end
            model.saved?.should be_false
          end

          it "does not change #dirty?" do
            model = valid_cassandra_model
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
          items = Array(MyModel::Cassandra).new
          5.times do
            items << MyModel::Cassandra.new(name: "query_me", default_value: UUID.random.to_s, not_nil_value: 12).save!
          end

          MyModel::Cassandra.first.should_not be_nil
        end
      end

      describe "#query" do
        it "with matching attributes" do
          items = Array(MyModel::Cassandra).new
          5.times do
            items << MyModel::Cassandra.new(name: "query_me", default_value: UUID.random.to_s, not_nil_value: 12).save!
          end

          results = MyModel::Cassandra.query(name: "query_me", not_nil_value: 12)
          results.should_not be_nil
          results.size.should eq 5
          items.each do |r|
            results.should contain r
          end
        end
      end

      it "#all" do
        MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Cassandra.new(name: "my_other_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Cassandra.all.size.should eq 2
      end

      it "#size" do
        MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Cassandra.new(name: "my_other_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Cassandra.size.should eq 2
      end

      it "#each" do
        MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
        MyModel::Cassandra.new(name: "my_other_name", default_value: UUID.random.to_s, not_nil_value: 1).save!

        called = 0
        MyModel::Cassandra.each do |r|
          r.should be_a MyModel::Cassandra
          called += 1
        end
        called.should be > 0
      end

      describe "limits" do
        it "#all" do
          MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
          MyModel::Cassandra.new(name: "my_other_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
          MyModel::Cassandra.all(limit: 1).size.should eq 1

          res = MyModel::Cassandra.all(limit: 1)
          res.size.should eq 1
        end

        it "#query" do
          MyModel::Cassandra.new(name: "my_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
          MyModel::Cassandra.new(name: "my_other_name", default_value: UUID.random.to_s, not_nil_value: 1).save!
          MyModel::Cassandra.all(limit: 1).size.should eq 1

          res = MyModel::Cassandra.query(limit: 1)
          res.size.should eq 1
        end
      end
    end
  end
end
