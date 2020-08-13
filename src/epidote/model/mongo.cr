require "json"
require "uuid"
require "uuid/json"

require "cryomongo"
require "../../epidote"
require "../adapter/mongo"
require "../macros/mongo"

abstract class Epidote::Model::Mongo < Epidote::Model
  include BSON::Serializable

  @[::JSON::Field(key: "_id")]
  @[::BSON::Field(key: "_id")]
  setter id : BSON::ObjectId = BSON::ObjectId.new

  @[::Epidote::DB::Model::Attr(name: :id, type: BSON::ObjectId, default: BSON::ObjectId.new,
    unique: true, index: true, primary_key: true)]
  def id : BSON::ObjectId
    @id
  end

  def self.adapter : Epidote::Adapter::Mongo.class
    Epidote::Adapter::Mongo
  end

  def adapter : Epidote::Adapter::Mongo.class
    Epidote::Model::Mongo.adapter
  end

  def id=(value : String)
    self.id = BSON::ObjectId.new(value)
  end
end
