require "json"
require "uuid"
require "uuid/json"

require "db"
require "mysql"
require "../../epidote"
require "../adapter/mysql"
require "../macros/mysql"

abstract class Epidote::Model::MySQL < Epidote::Model
  def self.adapter : Epidote::Adapter::MySQL.class
    Epidote::Adapter::MySQL
  end

  def adapter : Epidote::Adapter::MySQL.class
    Epidote::Model::MySQL.adapter
  end

  def self.first
    _query_all(limit: 1)[0]?
  rescue ex
    logger.error(exception: ex) { ex }
    nil
  end

  def self.drop
    logger.warn { "[#{Fiber.current.name}] dropping table: #{table_name}" }
    adapter.client.exec("DROP TABLE `#{table_name}`")
  end

  def self.truncate
    logger.warn { "[#{Fiber.current.name}] truncating table: #{table_name}" }
    adapter.client.exec("TRUNCATE TABLE `#{table_name}`")
  end

  def self.size(**args) : Int32 | Int64
    count = 0
    adapter.with_ro_database do |client_ro|
      sql = "SELECT count(*) FROM `#{self.table_name}` #{_where_query(**args)}"
      client_ro.query_one(sql) do |rs|
        count = rs.read(Int64)
      end
    end
    count
  end
end
