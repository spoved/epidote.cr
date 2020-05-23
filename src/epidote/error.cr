class Epidote::Error < Exception
  class ValidateFailed < Epidote::Error
    property nil_attrs = Array(String).new

    def message : String?
      "The following attributes cannot be nil: #{nil_attrs.join(',')}"
    end
  end

  class UnknownAttribute < Epidote::Error; end
end
