require "dotenv"
Dotenv.load if File.exists?(".env")

require "spec"
require "../src/epidote"

require "./fixtures"

Spec.before_suite {
  spoved_logger :trace, bind: true
}

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
