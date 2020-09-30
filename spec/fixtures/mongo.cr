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

class MyOtherModel::Mongo < Epidote::Model::Mongo
  collection(:my_other_model)

  attribute :metadata, Hash(String, String)
  attribute :labels, Array(String)
  attribute :uuid, UUID
  attribute :extra_data, JSON::Any

  @[BSON::Field(ignore: true)]
  @[JSON::Field(ignore: true)]
  @pre_commit_calls = 0

  def pre_commit_calls
    @pre_commit_calls
  end

  pre_commit ->{
    @pre_commit_calls += 1
  }

  @[BSON::Field(ignore: true)]
  @[JSON::Field(ignore: true)]
  @post_commit_calls = 0

  def post_commit_calls
    @post_commit_calls
  end

  post_commit ->{
    @post_commit_calls += 1
  }
end

class BoolTestModel::Mongo < Epidote::Model::Mongo
  collection(:bool_test_model)
  attribute :active, Bool, default: false, not_nil: true
end

class SubHashModel::Mongo < Epidote::Model::Mongo
  collection(:sub_hash_model)
  attribute :extra_data, Hash(String, String | Array(String))
end
