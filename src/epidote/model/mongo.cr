require "json"
require "uuid"
require "uuid/json"

require "mongo"
require "../../epidote"
require "../macros/mongo"

abstract class Epidote::Model::Mongo < Epidote::Model
  @[::JSON::Field(key: "_id")]
  @[::Epidote::DB::Model::Attr(name: :id, type: BSON::ObjectId, unique: true, index: true)]
  setter id : BSON::ObjectId = BSON::ObjectId.new

  @[::Epidote::DB::Model::Attr(name: :id, type: BSON::ObjectId, default: BSON::ObjectId.new, unique: true, index: true)]
  def id : BSON::ObjectId
    @id
  end

  def id=(value : String)
    self.id = BSON::ObjectId.new value
  end

  def _insert_record
  end

  def _delete_record
  end

  def _update_record
  end
end
