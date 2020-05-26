require "dotenv"
Dotenv.load if File.exists?(".env")

require "spec"
require "../src/epidote"

spoved_logger(bind: true, level: :error)
# ::Mongo.logger.level = :debug

require "./fixtures"

Spec.before_suite do
  begin
    MyModel::Mongo.drop
    MyModel::Mongo.init_collection!
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
  end
end

Spec.before_each do
  begin
    MyModel::Mongo.each &.destroy
    MyModel::MySQL.truncate
  rescue ex
    Log.error(exception: ex) { ex.message }
    Log.error(exception: ex) { ex.backtrace }
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

def invalid_mysql_model
  model = MyModel::MySQL.new(id: rand(99999), name: "my_name", unique_name: UUID.random.to_s)
  model.valid?.should be_false
  model
end

def valid_mysql_model
  model = MyModel::MySQL.new(id: rand(99999), name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
  model.valid?.should be_true
  model
end
