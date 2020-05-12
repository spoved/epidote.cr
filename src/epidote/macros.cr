require "spoved/logger"
require "json"

abstract class Epidote::Model
  macro attribute(name, type, **options)
    @[::JSON::Field]
    setter {{name.id}} : {{type}} {% if options[:default] %}= {{options[:default]}} {% end %}

    @[::Epidote::DB::Model::Attr(
      name: :{{name.id}},
      type: {{type}},
      {% for k, v in options %}
      {{k}}: {{v}},
      {% end %}
    )]
    def {{name.id}} : {{type}}
      @{{name.id}}
    end
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
              {% unless anno[:default] %}
                @{{name}} : {{ anno[:type] }},
              {% end %}
            {% end %}

            {% for name, anno in properties %}
              {% if anno[:default] %}
                @{{name}} : {{ anno[:type] }} = {{anno[:default]}},
              {% end %}
            {% end %}
          )
          end
        {% end %}
      {% end %}
    end

  end
end
