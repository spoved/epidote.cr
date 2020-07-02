require "cryomongo"

class Mongo::Database
  def has_collection?(name)
    list_collections(name_only: true).each do |col|
      return true if name == col["name"]
    end
    false
  end
end
