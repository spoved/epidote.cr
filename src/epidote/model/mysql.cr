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
end
