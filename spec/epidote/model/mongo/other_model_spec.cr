require "../../../spec_helper"

Spec.before_suite do
  begin
    MyOtherModel::Mongo.drop
    MyOtherModel::Mongo.init_collection!
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

Spec.before_each do
  begin
    MyOtherModel::Mongo.each &.destroy
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

describe MyOtherModel::Mongo do
  describe "attributes" do
    it "can accept Hash" do
      model = MyOtherModel::Mongo.new(metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"])
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.metadata.should eq ({"key" => "value"})
    end

    it "can accept Array" do
      model = MyOtherModel::Mongo.new(metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"])
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.labels.should eq (["label1", "label2"])
    end

    it "can accept UUID" do
      uuid = UUID.random
      model = MyOtherModel::Mongo.new(metadata: {"key" => "value"}, uuid: uuid, labels: ["label1", "label2"])
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.uuid.should eq (uuid)
    end
  end

  describe "commit hooks" do
    describe "#save" do
      it "calls hooks" do
        model = MyOtherModel::Mongo.new(metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"])
        model.pre_commit_calls.should eq 0
        model.post_commit_calls.should eq 0
        model.save!
        model.pre_commit_calls.should eq 1
        model.post_commit_calls.should eq 1
      end
    end

    describe "#update" do
      it "calls hooks" do
        model = MyOtherModel::Mongo.new(metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"])
        model.save!

        model.pre_commit_calls.should eq 1
        model.post_commit_calls.should eq 1
        model.update
        model.pre_commit_calls.should eq 2
        model.post_commit_calls.should eq 2
      end
    end
  end
end
