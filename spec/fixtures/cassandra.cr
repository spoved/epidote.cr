class MyModel::Cassandra < Epidote::Model::Cassandra
  table(:my_model)
  attributes(
    uuid: {
      primary_key: true,
      type:        UUID,
      default:     UUID.random,
    },
    name: String,
  )
  attribute :default_value, String, default: "a string"
  attribute :not_nil_value, Int32, not_nil: true
end
