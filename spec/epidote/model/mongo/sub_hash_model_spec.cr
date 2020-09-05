require "../../../spec_helper"

Spec.before_suite do
  begin
    SubHashModel::Mongo.drop
    SubHashModel::Mongo.init_collection!
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

Spec.before_each do
  begin
    SubHashModel::Mongo.each &.destroy
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

describe SubHashModel::Mongo do
  it "can be saved" do
    data = {
      "data"  => "data",
      "value" => ["stuff"],
    }
    model = SubHashModel::Mongo.new(extra_data: data)
    model.save!

    m = SubHashModel::Mongo.find(model.id)
    m.should_not be_nil
    m.not_nil!.extra_data.not_nil!.should eq data
  end
end
