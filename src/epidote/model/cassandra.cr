require "json"
require "uuid"
require "uuid/json"

require "db"
require "cassandra/dbapi"
require "../../epidote"
require "../adapter/cassandra"
require "../macros/cassandra"

abstract class Epidote::Model::Cassandra < Epidote::Model
  def self.adapter : Epidote::Adapter::Cassandra.class
    Epidote::Adapter::Cassandra
  end

  def adapter : Epidote::Adapter::Cassandra.class
    Epidote::Model::Cassandra.adapter
  end

  def self.first
    _query_all(limit: 1)[0]?
  rescue ex
    logger.error(exception: ex) { "[#{Fiber.current.name}] #{ex.message}" }
    nil
  end

  def self.drop
    logger.warn { "[#{Fiber.current.name}] dropping table: #{table_name}" }
    adapter.client.exec("DROP TABLE if exists #{table_name}")
  end

  def self.truncate
    logger.warn { "[#{Fiber.current.name}] truncating table: #{table_name}" }
    adapter.client.exec("TRUNCATE TABLE #{table_name}")
  end

  def self.size(**args) : Int32 | Int64
    count = 0
    adapter.with_ro_database do |client_ro|
      sql = "SELECT count(*) FROM #{self.table_name} #{_where_query(**args)}"
      client_ro.query_one(sql) do |rs|
        count = rs.read(Int64)
      end
    end
    count
  end
end
