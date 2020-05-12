require "../src/epidote/model/mongo"

class MyModel::Mongo < Epidote::Model::Mongo
  collection(:my_model)
  attributes(name: String, unique_name: {
    index:  true,
    unique: true,
    type:   String,
  })
  attribute :default_value, String, default: "a string"
end
