require "dotenv"
Dotenv.load if File.exists?(".env")

require "spec"
require "../src/epidote"

# spoved_logger(bind: true)
# ::Mongo.logger.level = :debug

require "./fixtures"

Spec.before_suite do
  MyModel::Mongo.drop
  MyModel::Mongo.init_collection!
end

Spec.before_each do
  MyModel::Mongo.all.each do |r|
    begin
      r.destroy!
    rescue ex
      puts ex.inspect
    end
  end
end

def invalid_mongo_model
  model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s)
  model.valid?.should be_false
  model
end

def valid_mongo_model
  model = MyModel::Mongo.new(id: BSON::ObjectId.new, name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
  model.valid?.should be_true
  model
end
