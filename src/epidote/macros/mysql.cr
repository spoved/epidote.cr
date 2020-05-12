abstract class Epidote::Model::MySQL < Epidote::Model
  macro table(name)
    # Returns the table name this model is associated with
    def self.table_name : String
      {{name.id.stringify}}
    end
  end
end
