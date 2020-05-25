abstract class Epidote::Adapter
  macro inherited
    Log = ::Log.for(self)

    def self.logger
      Log
    end
  end
end
