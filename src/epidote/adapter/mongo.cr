require "../adapter"
require "cryomongo"

class Epidote::Adapter::Mongo < Epidote::Adapter
  MONGODB_DB_NAME = ENV["CRYSTAL_ENV"]? ? "#{ENV["MONGODB_DB_NAME"]}_#{ENV["CRYSTAL_ENV"]?}" : "#{ENV["MONGODB_DB_NAME"]}"

  MONGODB_URI = URI.new(
    scheme: "mongodb",
    host: ENV["MONGODB_HOST"]? || "localhost",
    port: (ENV["MONGODB_PORT"]? || 27017).to_i,
    user: ENV["MONGODB_USER"]? || "root",
    password: ENV["MONGODB_PASS"]? || ""
  )

  MONGODB_RO_URI = URI.new(
    scheme: "mongodb",
    host: ENV["MONGODB_RO_HOST"]? || ENV["MONGODB_HOST"]? || "localhost",
    port: (ENV["MONGODB_RO_PORT"]? || ENV["MONGODB_PORT"]? || 27017).to_i,
    # path: MONGODB_DB_NAME,
    user: ENV["MONGODB_USER"]? || "root",
    password: ENV["MONGODB_PASS"]? || ""
  )

  @@client : ::Mongo::Client? = nil
  @@client_ro : ::Mongo::Client? = nil

  # :nodoc:
  @@_mutex = Mutex.new
  # :nodoc:
  @@_ro_mutex = Mutex.new

  private def self.new_client(uri)
    logger.info { "[#{Fiber.current.name}] creating new mongo client" }
    ::Mongo::Client.new(uri, ::Mongo::Options.new(auth_mechanism: "SCRAM-SHA-1"))
  end

  protected def self.client : ::Mongo::Client
    unless @@client
      @@_mutex.synchronize do
        @@client = self.new_client(client_uri.to_s)
      end
    end
    @@client.not_nil!
  end

  protected def self.client_ro : ::Mongo::Client
    unless @@client_ro
      @@_ro_mutex.synchronize do
        @@client_ro = client_uri != client_ro_uri ? self.new_client(client_ro_uri.to_s) : client
      end
    end
    @@client_ro.not_nil!
  end

  def self.close
    @@_mutex.synchronize do
      unless @@client.nil?
        logger.debug { "[#{Fiber.current.name}] closing mongo client" }
        @@client.not_nil!.close
        @@client = nil
      end

      unless @@client_ro.nil?
        logger.debug { "[#{Fiber.current.name}] closing mongo RO client" }
        @@client_ro.not_nil!.close
        @@client_ro = nil
      end
    end
  end

  def self.client_name
    MONGODB_DB_NAME
  end

  def self.client_uri
    MONGODB_URI
  end

  def self.client_ro_uri
    MONGODB_RO_URI
  end

  def self.database_name
    MONGODB_DB_NAME
  end

  protected def self.with_database(&block : ::Mongo::Database -> Nil) : Nil
    yield client[self.database_name]
  rescue ex
    logger.error(exception: ex) { "[#{Fiber.current.name}] with_database: #{ex.message}" }
    logger.trace { ex.backtrace }
    raise ex
  end

  def self.with_collection(collection, &block : ::Mongo::Collection -> Nil) : Nil
    with_database do |db|
      yield db[collection]
    end
  rescue ex
    logger.error(exception: ex) { "[#{Fiber.current.name}] with_collection: #{ex.message}" }
    logger.trace { ex.backtrace }
    raise ex
  end
end

at_exit { Epidote::Adapter::Mongo.close }
