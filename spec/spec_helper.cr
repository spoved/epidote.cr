require "dotenv"
Dotenv.load if File.exists?(".env")

require "spec"
require "../src/epidote"
require "./fixtures"

Spec.before_suite do
  MyModel::Mongo.drop
  MyModel::Mongo.init_collection!
end
