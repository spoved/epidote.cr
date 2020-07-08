require "../spec_helper"

describe Epidote::Model do
  it "can have a default of false" do
    model = BoolTestModel::Mongo.new
    model.active.should be_false
  end
end
