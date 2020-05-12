abstract class Epidote::Model::Mongo < Epidote::Model
  macro collection(name)
    # Returns the collection name this model is associated with
    def self.collection_name : String
      {{name.id.stringify}}
    end
  end
end
