require "spoved/logger"
require "json"

abstract class Epidote::Model
  macro attribute(name, type, **options)
    @[::JSON::Field]
    @{{name.id}} : {{type}}? = {% if options[:default] %} {{options[:default]}} {% else %} nil {% end %}

    def {{name.id}}=(val : {{type}})
      @{{name.id}} = val
      mark_dirty
    end

    @[::Epidote::DB::Model::Attr(
      name: :{{name.id}},
      type: {{type}},
      {% for k, v in options %}
      {{k}}: {{v}},
      {% end %}
    )]
    {% if options[:not_nil] %}
    def {{name.id}} : {{type}}
      @{{name.id}}.not_nil!
    end
    {% else %}
    def {{name.id}} : {{type}}?
      @{{name.id}}
    end
    {% end %}
  end

  macro attributes(**args)
    {% for key, val in args %}
      {% if val.is_a?(NamedTupleLiteral) %}
      attribute( 
        name: {{key}}, 
        {% for k, v in val %}
        {{k}}: {{v}},
        {% end %}
      )
      {% else %}
      attribute {{key}}, {{val}}
      {% end %}
    {% end %}
  end

  macro define_static_methods
    # Queries for all records and yields each one
    def self.each(&block)
      self.all do |x|
        yield x
      end
    end
  end

  macro inherited
    {% unless @type.abstract? %}
      spoved_logger(bind: false)
      define_static_methods
      initializers
      {{@type.id}}._epidote_methods
    {% end %}
  end

  macro initializers
    macro finished
      {% verbatim do %}
        {% begin %}
          {% properties = {} of Nil => Nil %}
          {% for meth in @type.methods %}
            {% if meth.annotation(::Epidote::DB::Model::Attr) %}
              {% anno = meth.annotation(::Epidote::DB::Model::Attr) %}
              {% properties[meth.name] = anno %}
            {% end %}
          {% end %}

          # Check ancestors
          {% for ancestor in @type.ancestors %}
            {% for meth in ancestor.methods %}
              {% if meth.annotation(::Epidote::DB::Model::Attr) %}
                {% anno = meth.annotation(::Epidote::DB::Model::Attr) %}
                {% unless properties[meth.name] %}
                  {% properties[meth.name] = anno %}
                {% end %}
              {% end %}
            {% end %}
          {% end %}

          # Check found properties
          {% for name, anno in properties %}
          {% raise "Missing type for attribute #{name}" unless anno[:type] %}
          {% end %}

          def initialize(
            {% for name, anno in properties %}
              @{{name}} : {{ anno[:type] }}? = {% if anno[:default] %} {{anno[:default]}} {% else %} nil {% end %},
            {% end %}
          )
          end

          def valid? : Bool
            {% for name, anno in properties %}
              {% if anno[:not_nil] %}
                if @{{name}}.nil?
                  return false
                end
              {% end %}
            {% end %}
            true
          end

          def valid! : Bool
            error : Epidote::Error::ValidateFailed? = nil
            {% for name, anno in properties %}
              {% if anno[:not_nil] %}
                if @{{name}}.nil?
                  error = Epidote::Error::ValidateFailed.new if error.nil?
                  error.nil_attrs << {{name.id.stringify}}
                end
              {% end %}
            {% end %}
            raise error unless error.nil?
            true
          end

          # All the possible `typeof(val)` for each property
          alias ValTypes = Nil {% for name, anno in properties %} | {{anno[:type]}} {% end %}

          ATTR_TYPES = {
            {% for name, anno in properties %} :{{name.id}} => {{anno[:type]}}, {% end %}
          }

          ATTR_NAMES = [
            {% for name, anno in properties %} :{{name.id}}, {% end %}
          ]

          {% for name, anno in properties %}
            {% if name != "id" && anno[:index] %}
            add_index(keys: [{{name.stringify}}], unique: {{anno[:unique]}}, index_name: {{anno[:index_name]}} )

            {% end %}
          {% end %}

          # Array of all the attributes names
          protected def self.attributes : Array(Symbol)
            ATTR_NAMES
          end

          # Return an array containing all of the `{{@type}}` records
          def self.all : Array({{@type}})
            self._query_all
          end

          def get(name : Symbol)
            case name
            {% for name, anno in properties %}
            when :{{name.id}}
              self.{{name.id}}
            {% end %}
            else
              raise Epidote::Error::UnknownAttribute.new "Unknown attribute #{name}"
            end
          end

          def set(name : Symbol, value : ValTypes)
            case name
            {% for name, anno in properties %}
            when :{{name.id}}
              if value.is_a?({{anno[:type].id}})
                self.{{name.id}} = value.as({{anno[:type].id}})
                mark_dirty
              else
                raise Epidote::Error.new "Attribute #{name} must be type {{anno[:type].id}} not #{typeof(value)}"
              end
            {% end %}
            else
              raise Epidote::Error::UnknownAttribute.new "Unknown attribute #{name}"
            end
          end

          def update_attrs(changes : Hash(Symbol, ValTypes))
            changes.each do |n, v|
              raise "Unknown attribute" unless {{@type}}.attributes.includes?(n)
              raise "Can not change primary key" if n == :id

              self.set(n, v)
            end
          end
        {% end %}
      {% end %}
    end

  end
end
