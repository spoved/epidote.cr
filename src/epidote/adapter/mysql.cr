require "../adapter"
require "mysql"

class Epidote::Adapter::MySQL < Epidote::Adapter
  alias DataHash = Hash(String, Array(JSON::Any) | Bool | Float64 | Hash(String, JSON::Any) | Int64 | String | Nil)

  MYSQL_DB_NAME = ENV["CRYSTAL_ENV"]? ? "#{ENV["MYSQL_DB_NAME"]}_#{ENV["CRYSTAL_ENV"]?}" : "#{ENV["MYSQL_DB_NAME"]}"

  MYSQL_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_PORT"]? || 3306).to_i,
    path: "" + MYSQL_DB_NAME,
    # query: "schema=#{MYSQL_DB_NAME}",
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || ""
  )

  MYSQL_RO_URI = URI.new(
    scheme: "mysql",
    host: ENV["MYSQL_RO_HOST"]? || ENV["MYSQL_HOST"]? || "localhost",
    port: (ENV["MYSQL_RO_PORT"]? || ENV["MYSQL_PORT"]? || 3306).to_i,
    path: "" + MYSQL_DB_NAME,
    # query: "schema=#{MYSQL_DB_NAME}",
    user: ENV["MYSQL_USER"]? || "root",
    password: ENV["MYSQL_PASS"]? || ""
  )

  @@client : ::DB::Database? = nil
  @@client_ro : ::DB::Database? = nil

  private def self.new_client(uri)
    logger.info { "creating new MySQL client" }
    logger.trace { uri.to_s }

    ::DB.open uri
  end

  protected def self.client : ::DB::Database
    @@client ||= self.new_client(client_uri.to_s)
  end

  protected def self.client_ro : ::DB::Database
    @@client_ro ||= client_uri != client_ro_uri ? self.new_client(client_ro_uri.to_s) : client
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
    unless @@client.nil?
      logger.warn { "closing mysql client" }
      @@client.not_nil!.close
      @@client = nil
    end

    unless @@client_ro.nil?
      logger.warn { "closing mysql RO client" }
      @@client_ro.not_nil!.close
      @@client_ro = nil
    end
  end

  def self.init_database
    logger.info { "creating MySQL database: #{database_name}" }
    tmp_uri = client_uri.dup
    tmp_uri.path = ""
    tmp_client = new_client(tmp_uri.to_s)
    tmp_client.exec("create schema if not exists `#{database_name}`")
    tmp_client.close
  end

  def self.drop_database
    logger.warn { "dropping schema #{database_name}" }
    client.exec("drop schema if exists `#{database_name}`")
  end

  def self.with_rw_database(&block : ::DB::Connection -> Nil)
    client.using_connection(&block)
  end

  def self.with_ro_database(&block : ::DB::Connection -> Nil)
    client_ro.using_connection(&block)
  end
end

at_exit { Epidote::Adapter::MySQL.close }
