abstract class Epidote::Model::Cassandra < Epidote::Model
  alias Any = ::Cassandra::DBApi::Any

  macro table(name)
    TABLE_NAME = {{name.id.stringify}}
    # Returns the table name this model is associated with
    def self.table_name : String
      TABLE_NAME
    end
  end

  macro inherited
    Log = ::Log.for(self)
    INDEXES = Hash(Hash(String, Int32), NamedTuple(name: String, unique: Bool)).new
  end

  macro add_index(keys, **options)
    INDEXES[{
      {% for name in keys %}
      {{name.id.stringify}} => 1,
      {% end %}
    }] = {
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

          def_equals( {% for name, type in ATTR_TYPES %} @{{name.id}}, {% end %})

          RES_STRUCTURE = {
            {% for name, val in ATTR_TYPES %}
              {% if val.id == "UUID" %}
                {{name.id}}: ::Cassandra::DBApi::Uuid,
              {% elsif val.id == "JSON::Any" %}
                {{name.id}}: String?,
              {% else %}
                {{name.id}}: ::{{val.id.gsub(/^::/, "")}},
              {% end %}
            {% end %}
          }

          NON_ID_ATTR = [
            {% for key in ATTR_TYPES.keys.reject(&.id.==(PRIMARY_KEY.id)) %}
            {{key.id.stringify}},
            {% end %}
          ]

          protected def self.non_id_attributes
            NON_ID_ATTR
          end

          # Alias of each `key => typeof(val)` in a `NamedTuple`
          alias RespTuple = NamedTuple(
            {% for name, val in ATTR_TYPES %}
              {% if val.id == "UUID" %}
                {{name.id}}: ::Cassandra::DBApi::Uuid,
              {% elsif val.id == "JSON::Any" %}
                {{name.id}}: String?,
              {% else %}
                {{name.id}}: ::{{val.id.gsub(/^::/, "")}},
              {% end %}
            {% end %}
          )

          # Will convert the `{{@type}}::RespTuple` into an object
          protected def self.from_named_truple(res : RespTuple) : {{ @type }}
            {{@type}}.new(
              {% for name, val in ATTR_TYPES %}
                {% if val.id == "UUID" %}
                  {{name.id}}: UUID.new(res[:{{name.id}}].as(::Cassandra::DBApi::Uuid).to_s),
                {% elsif val.id == "JSON::Any" %}
                  {{name.id}}: res[:{{name.id}}].nil? ? nil : JSON.parse(res[:{{name.id}}].as(String)),
                {% else %}
                  {{name.id}}: res[:{{name.id}}],
                {% end %}
              {% end %}
            )
          end

          private def self._query_all(limit : Int32 = 0, offset : Int32 = 0, where = "")
            logger.trace { "querying all records"}
            sql = "SELECT #{{{@type}}.attributes.join(", ")} FROM #{self.table_name} #{where} "
            sql += _limit_query(limit, offset)
            sql += " ALLOW FILTERING" unless where.empty?
            logger.trace { "_query_all: #{sql}"}

            results : Array({{@type}}) = Array({{@type}}).new
            adapter.with_ro_database do |client_ro|
              results = client_ro.query_all(sql, as: RES_STRUCTURE).map{ |r| self.from_named_truple(r).mark_saved.mark_clean.as({{@type}}) }
            end
            results
          end

          def self.each(where = "", &block : {{@type}} -> _)
            sql = "SELECT #{{{@type}}.attributes.join(", ")} FROM #{self.table_name} #{where}"
            logger.trace { "each: #{sql}"}

            adapter.with_ro_database &.query_all(sql, as: RES_STRUCTURE).map do |r|
              block.call self.from_named_truple(r).mark_saved.mark_clean.as({{@type}})
            end
          end

          def self.find(id)
            sql = "SELECT #{{{@type}}.attributes.join(", ")} FROM #{self.table_name} "\
              "WHERE #{{{@type}}.primary_key_name} = ?"
            logger.trace { "find: #{sql}; id: #{id}"}
            item : {{@type}}? = nil
            adapter.with_ro_database do |client_ro|
              resp = client_ro.query_one(sql, id, as: RES_STRUCTURE)
              item = self.from_named_truple(resp).mark_saved.mark_clean.as({{@type}})
            end
            item
          rescue ex : DB::NoResultsError
            nil
          end

          def self._limit_query(limit : Int32 = 0, offset : Int32 = 0) : String
            if limit <= 0
              ""
            else
              String.build do |io|
                io << "LIMIT #{limit} "
                # if offset > 0
                #   io << "OFFSET #{offset} "
                # end
              end
            end
          end


          SUBS = {
            '\''  => "''",
          }

          def self._where_query(
              {% for name, val in ATTR_TYPES %}
                {{name.id}} : {{val}}? = nil,
              {% end %}
          ) : String

            where = String.build do |io|
              {% for name, val in ATTR_TYPES %}
                unless {{name.id}}.nil?
                  io << "{{name.id}} = "
                {% if val.id == "UUID" %}
                  io << {{name.id}}.to_s
                {% elsif val.id == "JSON::Any" %}
                  io << "'" << {{name.id}}.to_json.gsub(SUBS) << "'"
                {% elsif val.id == "String" %}
                  io << "'" << {{name.id}}.to_s.gsub(SUBS) << "'"
                {% elsif val.id == "Bool" %}
                  io << {{name.id}}.to_s
                {% else %}
                  io << {{name.id}}.to_s
                {% end %}
                  io << " AND "
                end
              {% end %}
            end
            where.empty? ? where : "WHERE #{where.chomp(" AND ")} "
          end

          def self.query(
            limit : Int32 = 0,
            offset : Int32 = 0,
            **args,
          )

            where = _where_query(**args)
            self._query_all(limit, offset, where)
          end

          def self.bulk_create(items : Array({{@type}}))
            if items.empty?
              logger.trace { "[#{Fiber.current.name}] empty list passed to {{@type}}.bulk_create" }
              return
            end

            cols = {{@type}}.attributes.map {|x| "`#{x}`"}
            qs = "(#{cols.map { "?" }.join(", ")})"
            sql_build = String::Builder.new("INSERT INTO #{ {{@type}}.table_name } (#{cols.join(", ")}) VALUES ")

            items.size.times do
              sql_build << qs << ","
            end
            sql = sql_build.to_s.chomp(',')

            logger.trace { "[#{Fiber.current.name}] bulk_create for #{items.size}"}

            values = Array(ValTypes).new(items.size)
            items.each do |i|
              i._pre_commit_hook
              {% for key in ATTR_TYPES.keys %}
              values << i.{{key.id}}
              {% end %}
            end

            resp : DB::ExecResult? = nil
            adapter.with_rw_database do |conn|
              resp = conn.exec(sql, args: values)
            end
            items.each &._post_commit_hook
          end

          def _delete_record
            sql = "DELETE FROM #{ {{@type}}.table_name } "\
              "WHERE #{{{@type}}.primary_key_name} = ?"

            logger.trace { "[#{Fiber.current.name}] _delete_record: #{sql}"}
            adapter.with_rw_database do |conn|
              conn.exec(sql, self.primary_key_val)
            end
          end

          def _insert_record
            _cols = {{@type}}.attributes.map {|x| "?"}

            sql = "INSERT INTO #{ {{@type}}.table_name } (#{{{@type}}.attributes.join(", ")}) VALUES (#{_cols.join(", ")})"
            logger.trace { "[#{Fiber.current.name}] _insert_record: #{sql}"}

            resp : DB::ExecResult? = nil
            adapter.with_rw_database do |conn|
              resp = conn.exec(sql,
                {% for key in ATTR_TYPES.keys %}
                self.{{key.id}},
                {% end %}
              )
            end

            {% if PRIMARY_TYPE.id == "Int32" %}
            if resp.not_nil!.rows_affected > 0 && primary_key_val.nil? && resp.not_nil!.last_insert_id > 0
              self.set({{@type}}.primary_key_name, resp.not_nil!.last_insert_id.to_i32)
            end
            {% elsif PRIMARY_TYPE.id == "Int64" %}
            if resp.not_nil!.rows_affected > 0 && primary_key_val.nil? && resp.not_nil!.last_insert_id > 0
              self.set({{@type}}.primary_key_name, resp.not_nil!.last_insert_id)
            end
            {% end %}
          end

          def _update_record
            _cols = {{@type}}.non_id_attributes.map { |x| "#{x} = ?" }

            sql = "UPDATE #{{{@type}}.table_name} SET #{_cols.join(", ")} "\
              "WHERE #{{{@type}}.primary_key_name} = ?"

            logger.trace { "[#{Fiber.current.name}] _update_record: #{sql}"}
            adapter.with_rw_database do |conn|
              conn.exec(sql,
                {% for key in ATTR_TYPES.keys.reject { |x| x.id == PRIMARY_KEY.id } %}
                self.{{key.id}},
                {% end %}
                self.primary_key_val
              )
            end
          end
        {% end %}
      {% end %}
    end
  end
end
