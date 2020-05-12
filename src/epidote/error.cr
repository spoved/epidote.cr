class Epidote::Error < Exception
  class ValidateFailed < Epidote::Error
    @attributes = Array(String).new
  end
end
