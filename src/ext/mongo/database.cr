require "cryomongo"

class Mongo::Database
  def has_collection?(name)
    list_collections(name_only: true).each do |col|
      puts col.inspect
      return true if name == col
    end
    false
  end
end
