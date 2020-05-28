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
      model = MyOtherModel::Mongo.new metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"]
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.metadata.should eq ({"key" => "value"})
    end

    it "can accept Array" do
      model = MyOtherModel::Mongo.new metadata: {"key" => "value"}, uuid: UUID.random, labels: ["label1", "label2"]
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.labels.should eq (["label1", "label2"])
    end

    it "can accept UUID" do
      uuid = UUID.random
      model = MyOtherModel::Mongo.new metadata: {"key" => "value"}, uuid: uuid, labels: ["label1", "label2"]
      model.save!
      qmodel = MyOtherModel::Mongo.find(model.id)
      qmodel.should_not be_nil
      qmodel.not_nil!.uuid.should eq (uuid)
    end
  end
end
