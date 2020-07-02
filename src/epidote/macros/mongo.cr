abstract class Epidote::Model::Mongo < Epidote::Model
  macro collection(name)
    COLLECTION = {{name.id.stringify}}

    # Returns the collection name this model is associated with
    def self.collection_name : String
      COLLECTION
    end
  end

  macro inherited
    Log = ::Log.for(self)
    INDEXES = Hash(BSON, NamedTuple(name: String, unique: Bool)).new
  end

  macro add_index(keys, **options)
    INDEXES[{
      {% for name in keys %}
      {{name.id.stringify}} => 1,
      {% end %}
    }.to_bson] = {
        {% if options[:index_name] %}
        name: {{options[:index_name].stringify}},
        {% else %}
        name: "_index_{{keys.join("_").id}}",
        {% end %}
        {% if options[:unique] %}
        unique: true,
        {% end %}
    }
  end

  macro _epidote_methods
    macro finished
      {% verbatim do %}
        {% begin %}

          def self.drop
            logger.warn { "dropping collection: #{COLLECTION}"}
            adapter.with_database do |db|
              db.client.command(::Mongo::Commands::Drop, database: db.name, name: COLLECTION)
            end
          end

          def self.init_collection!(options : BSON? = nil)
            logger.warn { "initializing collection: #{COLLECTION}"}

            adapter.with_database do |db|
              if db.has_collection?(COLLECTION)
                raise Epidote::Error.new("Collection #{COLLECTION} already exists")
              else
                logger.debug { "creating collection: #{COLLECTION}" }
                db.client.command(::Mongo::Commands::Create, database: db.name, name: COLLECTION, options: options)

                logger.debug { "adding indexes to collection: #{COLLECTION}" }
                adapter.with_collection(COLLECTION) do |coll|
                  INDEXES.each do |index, opts|
                    coll.create_index(index, options: opts)
                  end
                end
              end
            end
          end

          def_equals( {% for name, type in ATTR_TYPES %} @{{name.id}}, {% end %})

          def self.with_collection(&block : ::Mongo::Collection -> Nil) : Nil
            adapter.with_collection(COLLECTION, &block)
          end

          def with_collection(&block : ::Mongo::Collection -> Nil) : Nil
            {{@type}}.with_collection(&block)
          end

          def self.from_bson(bson : BSON)
            logger.trace { "raw bson: #{bson}"}
            new_ob = self.allocate
            bson.each do |%key, %value|
              case %key
              when "_id"
                if %value.is_a?(String)
                  new_ob.id = BSON::ObjectId.new(%value)
                else
                  new_ob.id =  %value.as(BSON::ObjectId)
                end
              {% for name, typ in ATTR_TYPES %}
              when {{name.id.stringify}}
                  if %value.is_a?({{typ.id}})
                    new_ob.{{name.id}} = %value
                  else
                      case %value
                      when String
                        {% if typ.id == "UUID" %}
                        new_ob.{{name.id}} = UUID.new(%value) 
                        {% else %}
                        raise "Unable to set value {{name.id}} for type {{typ.id}} value is a: #{%value.class}"
                        {% end %}
                      when Int64
                        {% if typ.id == "Int32" %}
                        new_ob.{{name.id}} = %value.to_i32
                        {% else %}
                        raise "Unable to set value {{name.id}} for type {{typ.id}} value is a: #{%value.class}"
                        {% end %}
                      else
                        {% if typ.resolve <= BSON::Serializable || typ.resolve.class.has_method? :from_bson %}
                          new_ob.{{name.id}} = {{typ.id}}.from_bson %value              
                        {% else %}
                          raise "Unable to set value {{name.id}} for type {{typ.id}} value is a: #{%value.class}"
                        {% end %}
                      end
                    end
              {% end %}
              else
                raise "Unable to set #{%key} with #{%value.inspect}"
              end
            end
            new_ob
          end

          private def self._query_all
            logger.trace { "querying all records"}

            results = [] of {{@type}}
            with_collection do |coll|
              coll.find(BSON.new).each do |doc|
                results << from_bson(doc).mark_saved.mark_clean
              end
            end
            results
          end

          def self.each(&block : {{@type}} -> _)
            with_collection do |coll|
              coll.find(BSON.new).each do |doc|
                block.call from_bson(doc).mark_saved.mark_clean
              end
            end
          end

          def self.query(
            {% for name, type in ATTR_TYPES %}
              {{name.id}} : {{type}}? = nil,
            {% end %}
          ) : Array({{@type}})

            %query = Hash(String, ValTypes).new

            {% for name, type in ATTR_TYPES %}
            %query[{{name.id.stringify}}] = {{name.id}} unless {{name.id}}.nil?
            {% end %}

            results = Array({{@type}}).new
            with_collection do |col|
              res = col.find(%query)
              logger.debug { "query: #{%query}" }
              res.each do |r|
                results << from_bson(r)
              end
              # result = from_bson(bson) unless bson.nil?
            end

            results
          rescue ex
            logger.error(exception: ex) { "Error when trying to locate record with id: #{id.to_s}" }
            Array({{@type}}).new
          end

          # Find a single record based on primary key
          def self.find(id : BSON::ObjectId) : {{@type}}?
            result : {{@type}}? = nil
            with_collection do |col|
              bson = col.find_one({"_id" => id})
              logger.debug { "find: id: #{id.to_s} returned: #{bson.to_json}" }
              result = from_bson(bson) unless bson.nil?
            end
            result
          rescue ex
            logger.error(exception: ex) { "Error when trying to locate record with id: #{id.to_s}" }
            nil
          end

          def _delete_record
            res = false
            self.with_collection do |coll|
              r = coll.delete_one({"_id" => id})
              unless r.nil?
                res = r.n == 1 ? true : false
              end
            end
            res
          end

          def _insert_record
            self.with_collection do |coll|
              doc = BSON.from_json(self.to_json)

              if doc.has_key?("id")
                doc["_id"] = BSON::ObjectId.new(doc["id"].to_s)
                doc["id"] = nil
              end

              r = coll.insert_one(doc)
              if !r.nil? && r.n == 1
                %id = doc["_id"].to_s.chomp('\u0000')
                logger.trace { "created record #{%id}" }
              end
            end
          end

          def _update_record
           {{@type}}.with_collection do |coll|
              coll.update_one({"_id" => id}, {"$set" => self.attr_string_hash})
            end
          end
        {% end %}
      {% end %}
    end
  end
end
