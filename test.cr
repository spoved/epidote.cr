require "dotenv"
Dotenv.load if File.exists?(".env")

require "./src/epidote"
require "./spec/fixtures"

def valid_mysql_model
  MyModel::MySQL.new(id: rand(99999), name: "my_name", unique_name: UUID.random.to_s, not_nil_value: 1)
end

5.times { valid_mysql_model.save! }

loop do
  begin
    puts "query"
    res = MyModel::MySQL.all
    puts "items: #{res.size}"
  rescue ex
    Log.error(exception: ex) { ex.message }
  end
  sleep 10
end
