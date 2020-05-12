require "json"
require "uuid"
require "uuid/json"

require "db"
require "mysql"
require "../../epidote"
require "../macros/mysql"

abstract class Epidote::Model::MySQL < Epidote::Model
  def _insert_record
  end

  def _delete_record
  end

  def _update_record
  end
end
