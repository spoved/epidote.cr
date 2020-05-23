require "../adapter"

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

  def self.client : ::Mongo::Client
    @@client ||= ::Mongo::Client.new client_uri.to_s
  end

  def self.client_ro : ::Mongo::Client
    @@client_ro ||= MONGODB_URI != MONGODB_RO_URI ? ::Mongo::Client.new(client_ro_uri.to_s) : client
  end

  def self.close
    client.close unless @@client.nil?
  end

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
    # rescue ex
    #   logger.error(exception: ex) { ex.message }
  end

  protected def self.with_collection(collection, &block : ::Mongo::Collection -> Nil) : Nil
    with_database do |db|
      yield db[collection]
    end
    # rescue ex
    #   logger.error(exception: ex) { ex.message }
  end
end
