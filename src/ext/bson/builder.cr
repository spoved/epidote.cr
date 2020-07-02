struct BSON
  private class Builder
    def []=(key : String, value : JSON::Any)
      self[key] = value.raw
    end
  end
end
