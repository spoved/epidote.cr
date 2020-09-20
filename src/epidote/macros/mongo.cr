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
        unique:  {% if options[:unique] %}true{% else %}false{% end %},
    }
  end

  macro _epidote_methods
    macro finished
      {% verbatim do %}
        {% begin %}
          {% converters = {} of SymbolLiteral => Path %}
          def self.drop
            logger.warn { "dropping collection: #{COLLECTION}"}
            adapter.with_database do |db|

              db.client.command(::Mongo::Commands::Drop, database: db.name, name: COLLECTION) if db.has_collection?(COLLECTION)
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

                  # Check to see if we have a converter provided. if so, use that instead.
                  {% meth = @type.methods.select { |m| m.name == name }.first %}
                  {% if meth.is_a?(Def) && meth.annotation(::Epidote::DB::Model::Attr) && meth.annotation(::Epidote::DB::Model::Attr).named_args[:converter] %}
                    {% anno = meth.annotation(::Epidote::DB::Model::Attr) %}
                    {% if anno && anno.named_args[:converter] %}
                    {% converters[name] = anno.named_args[:converter] %}
                    new_ob.{{name.id}} = {{anno.named_args[:converter]}}.from_bson %value
                    {% end %}
                  {% else %}

                  # Since no converter was provided we need to try to match the BSON type
                  # return to target return and do any needed coversions

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
              {% end %}
              else
                raise "Unable to set #{%key} with #{%value.inspect}"
              end
            end
            new_ob
          end

          private def self._query_all(query : BSON = BSON.new, limit : Int32 = 0, offset : Int32 = 0)
            logger.trace { "querying all records"}

            results = [] of {{@type}}
            with_collection do |coll|
              coll.find(BSON.new, limit: (limit <= 0 ? nil : limit), skip: (offset <= 0 ? nil : offset)).each do |doc|
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

          def self._where_query(
            {% for name, val in ATTR_TYPES %}
              {{name.id}} : {{val}}? = nil,
            {% end %}

            {% for name, val in ATTR_TYPES %}
              {% if val.id == "String" %}
              {{name.id}}_like : {{val}}? = nil,
              {% end %}
            {% end %}

            index_contains : String? = nil,
          )
            %query = Hash(String, ValTypes | Hash(String, String)).new
            {% for name, type in ATTR_TYPES %}
            {% if converters[name] %}
              %query[{{name.id.stringify}}] = {{converters[name]}}.to_bson({{name.id}}) unless {{name.id}}.nil?
            {% else %}
              %query[{{name.id.stringify}}] = {{name.id}} unless {{name.id}}.nil?
            {% end %}
            {% end %}


            {% for name, val in ATTR_TYPES %}
              {% if val.id == "String" %}
                unless {{name.id}}_like.nil?
                  %val = {{name.id}}_like
                  %query[{{name.id.stringify}}] = {
                    "$regex" => %val,
                    "$options" : "i",
                  }
                end
              {% end %}
            {% end %}


            unless index_contains.nil?
              %query["$text"] = { "$search" =>  index_contains }
            end

            %query
          end

          def self.query(
            limit : Int32 = 0,
            offset : Int32 = 0,
            **args
          ) : Array({{@type}})

            %query = _where_query(**args)
            results = Array({{@type}}).new

            with_collection do |col|
              logger.debug { "query: #{%query}" }
              res = col.find(%query, limit: (limit <= 0 ? nil : limit), skip: (offset <= 0 ? nil : offset) )
              res.each do |r|
                results << from_bson(r).mark_saved.mark_clean
              end
            end

            results
          rescue ex
            logger.error(exception: ex) { "Error when trying to locate record: #{args.to_s}" }
            Array({{@type}}).new
          end

          # Find a single record based on primary key
          def self.find(id : BSON::ObjectId) : {{@type}}?
            result : {{@type}}? = nil
            with_collection do |col|
              bson = col.find_one({"_id" => id})
              logger.debug { "find: id: #{id.to_s} returned: #{bson.to_json}" }
              result = from_bson(bson).mark_saved.mark_clean unless bson.nil?
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
              # doc = BSON.from_json(self.to_json)
              doc = self.to_bson

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
