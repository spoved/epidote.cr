require "spoved/logger"
require "json"

abstract class Epidote::Model
  macro attribute(name, type, **options)
    @[::JSON::Field]
    setter {{name.id}} : {{type}}? = {% if options[:default] %} {{options[:default]}} {% else %} nil {% end %}

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

          # Will check if the record is valid and return `false` if it is not
          def valid?
            {% for name, anno in properties %}
              {% if anno[:not_nil] %}
                if @{{name}}.nil?
                  return false
                end
              {% end %}
            {% end %}
            true
          end

          # Will check if the record is valid and raise an error if it is not
          def valid!
            {% for name, anno in properties %}
              {% if anno[:not_nil] %}
                if @{{name}}.nil?
                  raise "Attribute #{name} cannot be null!"
                end
              {% end %}
            {% end %}
          end
        {% end %}
      {% end %}
    end

  end
end
