abstract class Epidote::Model::Mongo < Epidote::Model
  macro collection(name)
    COLLECTION = {{name.id.stringify}}

    # Returns the collection name this model is associated with
    def self.collection_name : String
      COLLECTION
    end
  end

  macro inherited
    INDEXES = Hash(BSON, ::Mongo::IndexOpt).new
  end

  macro add_index(keys, unique = false, index_name = nil)
    INDEXES[{
      {% for name in keys %}
      {{name.id.stringify}} => 1,
      {% end %}
    }.to_bson] = ::Mongo::IndexOpt.new(
        {% if index_name %}
        name: {{index_name.stringify}},
        {% else %}
        name: "_index_{{keys.join("_").id}}",
        {% end %}
        {% if unique %}
        unique: true,
        {% end %}
      )
  end

  macro _epidote_methods
    macro finished
      {% verbatim do %}
        {% begin %}

          def self.drop
            adapter.with_database do |db|
              if db.has_collection?(COLLECTION)
                adapter.with_collection(COLLECTION, &.drop)
              end
            end
          end

          def self.init_collection!(options : BSON? = nil)
            adapter.with_database do |db|
              if db.has_collection?(COLLECTION)
                raise Epidote::Error.new("Collection #{COLLECTION} already exists")
              else
                db.create_collection(COLLECTION, options)
                adapter.with_collection(COLLECTION) do |coll|
                  INDEXES.each do |index, opts|
                    coll.create_index(index, opts)
                  end
                end
              end
            end
          end

          {% for name, type in ATTR_TYPES %}
          {% end %}

          def self.with_collection(&block : ::Mongo::Collection -> Nil) : Nil
            adapter.with_collection(COLLECTION, &block)
          end

          def with_collection(&block : ::Mongo::Collection -> Nil) : Nil
            {{@type}}.with_collection(&block)
          end

          alias DataHash = Hash(Symbol, ValTypes)

          def to_h : DataHash
            hash = DataHash.new
            {{@type}}.attributes.each do |k|
              hash[k] = get(k)
            end
            hash
          end

          private def attr_hash : DataHash
            hash = DataHash.new
            {{@type}}.attributes.each do |k|
              next if k == :id || k == :_id

              hash[k] = get(k)
            end
            hash
          end

          def self.from_bson(bson : BSON)
            new_ob = self.allocate
            bson.each_key do |%key|
              %value = bson[%key]
              case %key
              when "_id"
                if %value.is_a?(String)
                  new_ob.id = BSON::ObjectId.new(%value)
                else
                  new_ob.id =  %value.as(BSON::ObjectId)
                end
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

          def _delete_record
            self.with_collection do |coll|
              coll.remove({"_id" => id})
              if (err = coll.last_error)
                return err["nRemoved"] == 1 ? true : false
              else
                return false
              end
            end
            false
          end

          def _insert_record
            self.with_collection do |coll|
              doc = BSON.from_json(self.to_json)

              if doc.has_key?("id")
                doc["_id"] = BSON::ObjectId.new(doc["id"].to_s)
                doc["id"] = nil
              end

              coll.insert(doc)
              if (err = coll.last_error)
                %id = doc["_id"].to_s.chomp('\u0000')
                logger.debug { "created record #{%id}" }
              end
            end
          end


          def _update_record
            {{@type}}.with_collection do |coll|
              coll.update({"_id" => id}, {"$set" => self.attr_hash})
            end
          end
        {% end %}
      {% end %}
    end
  end
end
