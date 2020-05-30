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
    _query_all("LIMIT 1")[0]?
  rescue ex
    logger.error { ex }
    nil
  end

  def self.drop
    logger.warn { "dropping table: #{table_name}" }
    adapter.client.exec("DROP TABLE `#{table_name}`")
  end

  def self.truncate
    logger.warn { "truncating table: #{table_name}" }
    adapter.client.exec("TRUNCATE TABLE `#{table_name}`")
  end
end
