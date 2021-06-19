require "../adapter"
require "mysql"

class Epidote::Adapter::MySQL < Epidote::Adapter
  alias DataHash = Hash(String, Array(JSON::Any) | Bool | Float64 | Hash(String, JSON::Any) | Int64 | String | Nil)

  OPTIONS = HTTP::Params.new({
    "initial_pool_size"   => [ENV.fetch("MYSQL_DB_INITIAL_POOL_SIZE", "1")],
    "max_pool_size"       => [ENV.fetch("MYSQL_DB_MAX_POOL_SIZE", "0")],
    "max_idle_pool_size"  => [ENV.fetch("MYSQL_DB_IDLE_POOL_SIZE", "1")],
    "checkout_timeout"    => [ENV.fetch("MYSQL_DB_CHECKOUT_TIMEOUT", "5.0")],
    "retry_attempts"      => [ENV.fetch("MYSQL_DB_RETRY_ATTEMPTS", "1")],
    "retry_delay"         => [ENV.fetch("MYSQL_DB_RETRY_DELAY", "0.2")],
    "prepared_statements" => [ENV.fetch("MYSQL_DB_PREPARED_STATEMENTS", "true")],
  })

  USE_PREPARED_STMT = ENV.fetch("MYSQL_DB_PREPARED_STATEMENTS", "true") == "true"

  MYSQL_DB_NAME = ENV["CRYSTAL_ENV"]? ? "#{ENV["MYSQL_DB_NAME"]}_#{ENV["CRYSTAL_ENV"]?}" : "#{ENV["MYSQL_DB_NAME"]}"

  MYSQL_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_PORT"]? || "3306").to_i,
    path: "" + MYSQL_DB_NAME,
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || "",
    query: OPTIONS.to_s,
  )

  MYSQL_RO_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_RO_HOST"]? || ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_RO_PORT"]? || ENV["MYSQL_PORT"]? || "3306").to_i,
    path: "" + MYSQL_DB_NAME,
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || "",
    query: OPTIONS.to_s,
  )

  @@client : ::DB::Database? = nil
  @@client_ro : ::DB::Database? = nil

  # :nodoc:
  @@_mutex = Mutex.new
  # :nodoc:
  @@_ro_mutex = Mutex.new

  private def self.new_client(uri)
    logger.info { "[#{Fiber.current.name}] creating new MySQL client" }
    logger.trace { uri.to_s.gsub(ENV["MYSQL_PASS"]? || "", "REDACTED") }
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
    MYSQL_DB_NAME
  end

  def self.client_uri
    MYSQL_URI
  end

  def self.client_ro_uri
    MYSQL_RO_URI
  end

  def self.database_name
    MYSQL_DB_NAME
  end

  def self.close
    @@_mutex.synchronize do
      unless @@client.nil?
        logger.debug { "[#{Fiber.current.name}] closing mysql client" }
        @@client.not_nil!.close
        @@client = nil
      end

      unless @@client_ro.nil?
        logger.debug { "[#{Fiber.current.name}] closing mysql RO client" }
        @@client_ro.not_nil!.close
        @@client_ro = nil
      end
    end
  end

  def self.init_database
    logger.info { "[#{Fiber.current.name}] creating MySQL database: #{database_name}" }
    tmp_uri = client_uri.dup
    tmp_uri.path = ""
    tmp_client = new_client(tmp_uri.to_s)
    tmp_client.exec("create schema if not exists `#{database_name}`")
    tmp_client.close
  end

  def self.drop_database
    logger.warn { "[#{Fiber.current.name}] dropping schema #{database_name}" }
    client.exec("drop schema if exists `#{database_name}`")
  end

  def self.with_rw_database(&block : ::DB::Connection -> Nil)
    client.retry do
      begin
        client.using_connection(&block)
      rescue ex : IO::Error
        raise DB::ConnectionLost.new(client)
      end
    end
  end

  def self.with_ro_database(&block : ::DB::Connection -> Nil)
    client_ro.retry do
      begin
        client_ro.using_connection(&block)
      rescue ex : IO::Error
        raise DB::ConnectionLost.new(client)
      end
    end
  end
end

at_exit { Epidote::Adapter::MySQL.close }
