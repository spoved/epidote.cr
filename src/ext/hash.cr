require "bson"

class Hash(K, V)
  def to_bson(bson = BSON.new)
    # return BSON.from_json(self.to_json)
    each do |k, v|
      case v
      when .responds_to? :to_bson
        bson[k] = v.to_bson
      else
        bson[k] = v
      end
    end
    bson
  end
end
