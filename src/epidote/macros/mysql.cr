abstract class Epidote::Model::MySQL < Epidote::Model
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
              {% if val.id == "JSON::Any" %}
                {{name.id}}: String?,
              {% else %}
                {{name.id}}: ::{{val.id.gsub(/^::/, "")}},
              {% end %}
            {% end %}
          }

          NON_ID_ATTR = [
            {% for key in ATTR_TYPES.keys.reject { |x| x.id == PRIMARY_KEY.id } %}
            {{key.id.stringify}},
            {% end %}
          ]

          protected def self.non_id_attributes
            NON_ID_ATTR
          end

          # Alias of each `key => typeof(val)` in a `NamedTuple`
          alias RespTuple = NamedTuple(
            {% for name, val in ATTR_TYPES %}
              {% if val.id == "JSON::Any" %}
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
                {% if val.id == "JSON::Any" %}
                  {{name.id}}: res[:{{name.id}}].nil? ? nil : JSON.parse(res[:{{name.id}}].as(String)),
                {% else %}
                  {{name.id}}: res[:{{name.id}}],
                {% end %}
              {% end %}
            )
          end

          # :nodoc:
          private def self._query_all(limit : Int32 = 0, offset : Int32 = 0, where = "")
            logger.trace { "querying all records"}
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` "
            sql += where unless where.empty?
            sql += " ORDER BY `#{@@order_by.join("`,`")}` " unless @@order_by.empty?
            sql += _limit_query(limit, offset)

            logger.trace { "_query_all: #{sql}"}

            results : Array({{@type}}) = Array({{@type}}).new
            adapter.with_ro_database do |client_ro|
              results = client_ro.query_all(sql, as: RES_STRUCTURE).map{ |r| self.from_named_truple(r).mark_saved.mark_clean.as({{@type}}) }
            end
            results
          end


          def self.each(where = "", &block : {{@type}} -> _)
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` #{where}"
            sql += " ORDER BY `#{@@order_by.join("`,`")}`" unless @@order_by.empty?
            logger.trace { "each: #{sql}"}

            adapter.with_ro_database &.query_all(sql, as: RES_STRUCTURE).map do |r|
              block.call self.from_named_truple(r).mark_saved.mark_clean.as({{@type}})
            end
          end

          def self.find(id)
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` "\
              "WHERE `#{{{@type}}.primary_key_name}` = #{_prep_value(id)}"
            logger.trace { "find: #{sql}"}
            item : {{@type}}? = nil
            adapter.with_ro_database do |client_ro|
              resp = client_ro.query_one(sql, as: RES_STRUCTURE)
              item = self.from_named_truple(resp).mark_saved.mark_clean.as({{@type}})
            end
            item
          rescue ex : DB::NoResultsError
            nil
          end

          # :nodoc:
          def self._limit_query(limit : Int32 = 0, offset : Int32 = 0) : String
            if limit <= 0
              ""
            else
              String.build do |io|
                io << "LIMIT #{limit} "
                if offset > 0
                  io << "OFFSET #{offset} "
                end
              end
            end
          end

          # :nodoc:
          SUBS = {
            '"'  => "\\\"",
          }

          # :nodoc:
          def self._prep_value(val) : String
            case val
            when Nil
              "NULL"
            when UUID
              "UUID_TO_BIN('#{val.to_s}')"
            when JSON::Any
              %<"#{val.to_json.gsub(SUBS)}">
            when String
              if val =~ /'/
                %<"#{val.gsub(SUBS)}">
              else
                %<'#{val}'>
              end
            when Bool, Int32, Int64
              val.to_s
            when Time
             %<from_unixtime(#{val.to_unix})>
            else
              %<"#{val.to_s.gsub(SUBS)}">
            end
          end

          # :nodoc:
          private def _prep_value(val) : String
            {{@type}}._prep_value(val)
          end

          # :nodoc:
          private def _pk_select
            "`#{{{@type}}.primary_key_name}` = #{_prep_value(primary_key_val)}"
          end

          # :nodoc:
          def self._where_query(
              {% for name, val in ATTR_TYPES %}
                {{name.id}} : {{val}}? = nil,
              {% end %}

              {% for name, val in ATTR_TYPES %}
                {% if val.id == "String" %}
                {{name.id}}_like : {{val}}? = nil,
                {% elsif val.id == "Int32" || val.id == "Int64" %}
                {{name.id}}_gt : {{val}}? = nil,
                {{name.id}}_ge : {{val}}? = nil,
                {{name.id}}_lt : {{val}}? = nil,
                {{name.id}}_le : {{val}}? = nil,
                {% end %}
              {% end %}
          ) : String

            where = String.build do |io|
              {% for name, val in ATTR_TYPES %}
                unless {{name.id}}.nil?
                  io << "`{{name.id}}` = " << _prep_value({{name.id}})
                  io << " AND "
                end
              {% end %}

              {% for name, val in ATTR_TYPES %}
                {% if val.id == "String" %}
                  unless {{name.id}}_like.nil?
                    io << "`{{name.id}}` like "
                    io << '"' << '%' << {{name.id}}_like.to_s.gsub(SUBS) << '%' << '"'
                    io << " AND "
                  end
                {% elsif val.id == "Int32" || val.id == "Int64" %}
                  unless {{name.id}}_gt.nil?
                    io << "`{{name.id}}` > #{_prep_value({{name.id}}_gt)} "
                    io << " AND "
                  end

                  unless {{name.id}}_ge.nil?
                    io << "`{{name.id}}` >= #{_prep_value({{name.id}}_ge)} "
                    io << " AND "
                  end

                  unless {{name.id}}_lt.nil?
                    io << "`{{name.id}}` < #{_prep_value({{name.id}}_lt)} "
                    io << " AND "
                  end

                  unless {{name.id}}_le.nil?
                    io << "`{{name.id}}` <= #{_prep_value({{name.id}}_le)} "
                    io << " AND "
                  end
                {% end %}
              {% end %}
            end
            where.empty? ? where : "WHERE #{where.chomp(" AND ")}"
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
            %cols = {{@type}}.attributes.map {|x| "`#{x}`"}
            %qs = "(#{%cols.map { "?" }.join(", ")})"
            sql_build = String::Builder.new("INSERT IGNORE INTO `#{ {{@type}}.table_name }` (#{%cols.join(", ")}) VALUES ")

            items.each do |i|
              i._pre_commit_hook
              sql_build << '('
              sql_build << {{@type}}.attributes.map { |a| _prep_value(i.get(a)) }.join(", ")
              sql_build << "),"
            end
            sql = sql_build.to_s.chomp(',')

            logger.trace { "[#{Fiber.current.name}] bulk_create for #{items.size}"}

            resp : DB::ExecResult? = nil
            adapter.with_rw_database do |conn|
              resp = conn.exec(sql)
            end
            items.each &._post_commit_hook
          end

          # :nodoc:
          def _delete_record
            sql = "DELETE FROM `#{ {{@type}}.table_name }` "\
              "WHERE #{_pk_select}"

            logger.trace { "[#{Fiber.current.name}] _delete_record: #{sql}"}
            adapter.with_rw_database do |conn|
              conn.exec(sql)
            end
          end

          # :nodoc:
          def _insert_record
            %cols = {{@type}}.attributes.map {|x| "`#{x}` = #{_prep_value(get(x))}"}

            sql = "INSERT INTO `#{ {{@type}}.table_name }` SET #{%cols.join(",")}"
            logger.trace { "[#{Fiber.current.name}] _insert_record: #{sql}"}

            resp : DB::ExecResult? = nil
            adapter.with_rw_database do |conn|
              resp = conn.exec(sql)
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
            %cols = {{@type}}.non_id_attributes.map { |x| "`#{x}` = #{_prep_value(get(x))}" }

            sql = "UPDATE `#{{{@type}}.table_name}` SET #{%cols.join(",")} "\
              "WHERE #{_pk_select} "

            logger.trace { "[#{Fiber.current.name}] _update_record: #{sql}"}
            adapter.with_rw_database do |conn|
              conn.exec(sql)
            end
          end
        {% end %}
      {% end %}
    end
  end
end
