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

          def self.drop
            logger.warn { "dropping table: #{table_name}" }
            adapter.client.exec("DROP TABLE `#{table_name}`")
          end

          def self.truncate
            logger.warn { "dropping table: #{table_name}" }
            adapter.client.exec("TRUNCATE TABLE `#{table_name}`")
          end

          def_equals( {% for name, type in ATTR_TYPES %} @{{name.id}}, {% end %})

          RES_STRUCTURE = {
            {% for name, val in ATTR_TYPES %}
              {% if val.id == "UUID" || val.id == "JSON::Any" %}
                {{name.id}}: String,
              {% else %}
                {{name.id}}: {{val.id}},
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
              {% if val.id == "UUID" || val.id == "JSON::Any" %}
                {{name.id}}: String,
              {% else %}
                {{name.id}}: {{val.id}},
              {% end %}
            {% end %}
          )

          # Will convert the `{{@type}}::RespTuple` into an object
          protected def self.from_named_truple(res : RespTuple) : {{ @type }}
            {{@type}}.new(
              {% for name, val in ATTR_TYPES %}
                {% if val.id == "UUID" %}
                  {{name.id}}: UUID.new(res[:{{name.id}}].as(String)),
                {% elsif val.id == "JSON::Any" %}
                  {{name.id}}: JSON.parse(res[:{{name.id}}].as(String)),
                {% else %}
                  {{name.id}}: res[:{{name.id}}],
                {% end %}
              {% end %}
            )
          end

          private def self._query_all(where = "")
            logger.debug { "querying all records"}
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` #{where}"
            adapter.client_ro.query_all(sql, as: RES_STRUCTURE).map{ |r| self.from_named_truple(r).mark_saved.mark_clean }
          end


          def self.each(where = "", &block : {{@type}} -> _)
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` #{where}"
            adapter.client_ro.query_all(sql, as: RES_STRUCTURE).map do |r|
              block.call self.from_named_truple(r).mark_saved.mark_clean
            end
          end

          def self.find(id)
            sql = "SELECT `#{{{@type}}.attributes.join("`,`")}` FROM `#{self.table_name}` "\
            "WHERE `#{{{@type}}.primary_key_name}` = ?"
            resp = adapter.client_ro.query_one(sql, as: RES_STRUCTURE)
            self.from_named_truple(resp).mark_saved.mark_clean
          end

          def self.query(
            {% for name, val in ATTR_TYPES %}
              {{name.id}} : {{val}}? = nil,
            {% end %}
          )

            subs = {
              '"'  => "\\\"",
            }
            where = String.build do |io|
              io << "WHERE "
              {% for name, val in ATTR_TYPES %}
                unless {{name.id}}.nil?
                  io << "`{{name}}` = "
                {% if val.id == "UUID" %}
                  io << "'" << {{name.id}}.to_s << "'"
                {% elsif val.id == "JSON::Any" %}
                {% elsif val.id == "String" %}
                  io << "\"" << {{name.id}}.to_s.gsub(subs) << "\""
                {% else %}
                  io << "\"" << {{name.id}}.to_s.gsub(subs) << "\""
                {% end %}
                  io << " AND "
                end
              {% end %}
            end

            logger.debug { where.chomp(" AND ") }
            self._query_all(where.chomp(" AND "))
          end

          def _delete_record
              sql = "DELETE FROM `#{ {{@type}}.table_name }` "\
                "WHERE `#{{{@type}}.primary_key_name}` = ?"

            logger.debug { sql }
            adapter.client.exec(sql, self.primary_key_val)
          end

          def _insert_record
            %cols = {{@type}}.attributes.map {|x| "`#{x}` = ?"}

            sql = "INSERT INTO `#{ {{@type}}.table_name }` SET #{%cols.join(",")}"
            logger.debug { sql }
            adapter.client.exec(sql,
              {% for key in ATTR_TYPES.keys %}
              self.{{key.id}},
              {% end %}
            )
          end

          def _update_record
            %cols = {{@type}}.non_id_attributes.map {|x| "`#{x}` = ?"}

            sql = "UPDATE `#{{{@type}}.table_name}` SET #{%cols.join(",")} "\
              "WHERE `#{{{@type}}.primary_key_name}` = ?"

            logger.debug { sql }
            adapter.client.exec(sql,
              {% for key in ATTR_TYPES.keys.reject { |x| x.id == PRIMARY_KEY.id } %}
              self.{{key.id}},
              {% end %}
              self.primary_key_val
            )
          end
        {% end %}
      {% end %}
    end
  end
end
