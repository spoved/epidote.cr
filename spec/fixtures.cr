require "../src/epidote/model/*"

class MyModel::Mongo < Epidote::Model::Mongo
  collection(:my_model)
  attributes(name: String, unique_name: {
    index:  true,
    unique: true,
    type:   String,
  })
  attribute :default_value, String, default: "a string"
  attribute :not_nil_value, Int32, not_nil: true

  # attribute :uuid, UUID
  # attribute :extra_data, JSON::Any

  add_index [:id, :unique_name], unique: true
end

class MyModel::MySQL < Epidote::Model::MySQL
  table(:my_model)
  attributes(
    id: {
      primary_key:    true,
      type:           Int32,
      auto_increment: true,
    },
    name: String,
    unique_name: {
      index:  true,
      unique: true,
      type:   String,
    })
  attribute :default_value, String, default: "a string"
  attribute :not_nil_value, Int32, not_nil: true
  attribute :uuid, UUID
  attribute :extra_data, JSON::Any

  add_index [:id, :unique_name], unique: true
end
