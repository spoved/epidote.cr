require "../adapter"
require "cassandra/dbapi"

class Epidote::Adapter::Cassandra < Epidote::Adapter
  alias DataHash = Hash(String, Array(::Cassandra::DBApi::Any) | Bool | Float64 | Hash(String, ::Cassandra::DBApi::Any) | Int64 | String | Nil)

  OPTIONS = HTTP::Params.new({
    "initial_pool_size"  => [ENV.fetch("CASSANDRA_DB_INITIAL_POOL_SIZE", "1")],
    "max_pool_size"      => [ENV.fetch("CASSANDRA_DB_MAX_POOL_SIZE", "0")],
    "max_idle_pool_size" => [ENV.fetch("CASSANDRA_DB_IDLE_POOL_SIZE", "1")],
    "checkout_timeout"   => [ENV.fetch("CASSANDRA_DB_CHECKOUT_TIMEOUT", "5.0")],
    "retry_attempts"     => [ENV.fetch("CASSANDRA_DB_RETRY_ATTEMPTS", "1")],
    "retry_delay"        => [ENV.fetch("CASSANDRA_DB_RETRY_DELAY", "0.2")],
  })

  CASSANDRA_DB_NAME = ENV["CRYSTAL_ENV"]? ? "#{ENV["CASSANDRA_DB_NAME"]}_#{ENV["CRYSTAL_ENV"]?}" : "#{ENV["CASSANDRA_DB_NAME"]}"

  CASSANDRA_URI = URI.new(
    scheme: "cassandra",
    host: ENV["CASSANDRA_HOST"]? || "localhost",
    port: (ENV["CASSANDRA_PORT"]? || 9042).to_i,
    path: "" + CASSANDRA_DB_NAME,
    user: ENV["CASSANDRA_USER"]? || "cassandra",
    password: ENV["CASSANDRA_PASS"]? || "cassandra",
    query: OPTIONS.to_s,
  )

  CASSANDRA_RO_URI = URI.new(
    scheme: "cassandra",
    host: ENV["CASSANDRA_RO_HOST"]? || ENV["CASSANDRA_HOST"]? || "localhost",
    port: (ENV["CASSANDRA_RO_PORT"]? || ENV["CASSANDRA_PORT"]? || 9042).to_i,
    path: "" + CASSANDRA_DB_NAME,
    user: ENV["CASSANDRA_USER"]? || "cassandra",
    password: ENV["CASSANDRA_PASS"]? || "cassandra",
    query: OPTIONS.to_s,
  )

  @@client : ::DB::Database? = nil
  @@client_ro : ::DB::Database? = nil

  # :nodoc:
  @@_mutex = Mutex.new
  # :nodoc:
  @@_ro_mutex = Mutex.new

  private def self.new_client(uri)
    logger.info { "[#{Fiber.current.name}] creating new Cassandra client" }
    logger.trace { uri.to_s }
    ::DB.open uri
  end

  protected def self.client : ::DB::Database
    unless @@client
      @@_mutex.synchronize do
        @@client = self.new_client(client_uri.to_s)
      end
    end
    @@client.not_nil!
  end

  protected def self.client_ro : ::DB::Database
    unless @@client_ro
      @@_ro_mutex.synchronize do
        @@client_ro = client_uri != client_ro_uri ? self.new_client(client_ro_uri.to_s) : client
      end
    end
    @@client_ro.not_nil!
  end

  def self.client_name
    CASSANDRA_DB_NAME
  end

  def self.client_uri
    CASSANDRA_URI
  end

  def self.client_ro_uri
    CASSANDRA_RO_URI
  end

  def self.database_name
    CASSANDRA_DB_NAME
  end

  def self.close
    @@_mutex.synchronize do
      unless @@client.nil?
        logger.debug { "[#{Fiber.current.name}] closing cassandra client" }
        @@client.not_nil!.close
        @@client = nil
      end

      unless @@client_ro.nil?
        logger.debug { "[#{Fiber.current.name}] closing cassandra RO client" }
        @@client_ro.not_nil!.close
        @@client_ro = nil
      end
    end
  end

  def self.init_database
    logger.info { "[#{Fiber.current.name}] creating Cassandra database: #{database_name}" }
    tmp_uri = client_uri.dup
    tmp_uri.path = ""
    tmp_client = new_client(tmp_uri.to_s)
    tmp_client.exec("create keyspace if not exists #{database_name}")
    tmp_client.close
  end

  def self.drop_database
    logger.warn { "[#{Fiber.current.name}] dropping schema #{database_name}" }
    client.exec("drop keyspace if exists exists #{database_name}")
  end

  def self.with_rw_database(&block : ::DB::Connection -> Nil)
    client.retry do
      client.using_connection(&block)
    end
  end

  def self.with_ro_database(&block : ::DB::Connection -> Nil)
    client_ro.retry do
      client_ro.using_connection(&block)
    end
  end
end

at_exit { Epidote::Adapter::Cassandra.close }
