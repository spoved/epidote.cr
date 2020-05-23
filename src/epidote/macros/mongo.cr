abstract class Epidote::Model::Mongo < Epidote::Model
  macro collection(name)
    COLLECTION = {{name.id.stringify}}

    # Returns the collection name this model is associated with
    def self.collection_name : String
      COLLECTION
    end
  end

  macro _epidote_methods
    macro finished
      {% verbatim do %}
        {% begin %}

          {% for name, type in ATTR_TYPES %}

          {% end %}

          def self.with_collection(&block : ::Mongo::Collection -> Nil) : Nil
            adapter.with_collection(COLLECTION, &block)
          end

          alias DataHash = Hash(Symbol, ValTypes)

          private def to_hash : DataHash
            hash = DataHash.new
            attributes.each do |k|
              hash[k] = get(k)
            end
            hash
          end

          protected def self.from_bson(bson : BSON)
            new_ob = self.allocate
            bson.each_key do |%key|
              %value = bson[%key]
              case %key
              when "_id"
                new_ob.id = %value.as(BSON::ObjectId)
              {% for name, type in ATTR_TYPES %}
              when {{name.stringify}}
                new_ob.{{name.id}} = %value.as({{type.id}})
              {% end %}
              else
                raise "Unable to set #{%key} with #{%value.inspect}"
              end
            end
            new_ob
          end

          private def self._query_all
            results = [] of {{@type}}
            with_collection do |coll|
              coll.find(BSON.new) do |doc|
                results << from_bson(doc)
              end
            end
            results
          end

          def self.query(
            {% for name, type in ATTR_TYPES %}
              {{name.id}} : {{type}}? = nil,
            {% end %}
          )
          end

          # Find a single record based on primary key
          def self.find(id : String | BSON::ObjectId) : {{@type}}?
            result : {{@type}}? = nil
            with_collection do |col|
              bson = col.find_one({"_id" => id})
              result = from_bson(bson) unless bson.nil?
            end
            result
          rescue ex
            logger.error(exception: ex) { "Error when trying to locate record with id: #{id.to_s}" }
          end



        {% end %}
      {% end %}
    end
  end
end
