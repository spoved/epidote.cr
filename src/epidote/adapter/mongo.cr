require "../adapter"
require "mongo"

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

  @@client : ::Mongo::Client?
  @@client_ro : ::Mongo::Client?

  private def self.new_client(uri)
    logger.info { "creating new mongo client" }
    ::Mongo::Client.new uri
  end

  def self.client : ::Mongo::Client
    @@client ||= self.new_client(client_uri.to_s)
  end

  def self.client_ro : ::Mongo::Client
    @@client_ro ||= MONGODB_URI != MONGODB_RO_URI ? self.new_client(client_ro_uri.to_s) : client
  end

  # def self.close
  #   unless @@client.nil?
  #     logger.warn { "closing mongo client" }
  #     @@client.not_nil!.close
  #     @@client = nil
  #   end
  # end

  def self.client_name
    MONGODB_DB_NAME
  end

  def self.client_uri
    MONGODB_URI
  end

  def self.client_ro_uri
    MONGODB_URI
  end

  def self.database_name
    MONGODB_DB_NAME
  end

  protected def self.with_database(&block : ::Mongo::Database -> Nil) : Nil
    yield client[self.database_name]
  rescue ex
    logger.error(exception: ex) { "with_database: #{ex.message}" }
    logger.debug { ex.backtrace }
    raise ex
  end

  def self.with_collection(collection, &block : ::Mongo::Collection -> Nil) : Nil
    with_database do |db|
      yield db[collection]
    end
  rescue ex
    logger.error(exception: ex) { "with_collection: #{ex.message}" }
    logger.debug { ex.backtrace }
    raise ex
  end
end

# at_exit { Epidote::Adapter::Mongo.close }