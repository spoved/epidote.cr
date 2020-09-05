require "json"
require "uuid"
require "uuid/json"

require "cryomongo"
require "../../epidote"
require "../adapter/mongo"
require "../macros/mongo"

abstract class Epidote::Model::Mongo < Epidote::Model
  include BSON::Serializable

  struct ObjectIdConverter
    def self.from_json(pull : JSON::PullParser)
      string = pull.read_string
      BSON::ObjectId.new(string)
    end

    def self.to_json(value : BSON::ObjectId, json : JSON::Builder)
      value.to_s.to_json(json)
    end
  end

  @[::JSON::Field(converter: Epidote::Model::Mongo::ObjectIdConverter)]
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

  def self.size(**args) : Int32 | Int64
    count = 0
    with_collection do |coll|
      if args.empty?
        count = coll.estimated_document_count
      else
        count = coll.count_documents(_where_query(**args))
      end
    end
    count
  end
end
