module Cassandra
  module DBApi
    class ValueBinder
      private def do_bind(val : UUID)
        LibCass.statement_bind_uuid(@cass_stmt, @i, DBApi::Uuid.new(val.to_s))
      end

      private def do_bind(val : JSON::Any)
        sval = val.to_json
        LibCass.statement_bind_string_n(@cass_stmt, @i, sval, sval.bytesize)
      end
    end
  end
end
