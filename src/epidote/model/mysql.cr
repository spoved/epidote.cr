require "json"
require "uuid"
require "uuid/json"

require "db"
require "mysql"
require "../../epidote"
require "../adapter/mysql"
require "../macros/mysql"

abstract class Epidote::Model::MySQL < Epidote::Model
  def self.adapter : Epidote::Adapter::MySQL.class
    Epidote::Adapter::MySQL
  end

  def adapter : Epidote::Adapter::MySQL.class
    Epidote::Model::MySQL.adapter
  end

  def self.first
    _query_all(limit: 1)[0]?
  rescue ex
    logger.error(exception: ex) { "[#{Fiber.current.name}] #{ex.message}" }
    nil
  end

  def self.drop
    logger.warn { "[#{Fiber.current.name}] dropping table: #{table_name}" }
    adapter.client.exec("DROP TABLE `#{table_name}`")
  end

  def self.truncate
    logger.warn { "[#{Fiber.current.name}] truncating table: #{table_name}" }
    adapter.client.exec("TRUNCATE TABLE `#{table_name}`")
  end

  def self.size(**args) : Int32 | Int64
    count = 0
    adapter.with_ro_database do |client_ro|
      sql = "SELECT count(*) FROM `#{self.table_name}` #{_where_query(**args)}"
      client_ro.query_one(sql) do |rs|
        count = rs.read(Int64)
      end
    end
    count
  end

  def self.query(
    limit : Int32 = 0,
    offset : Int32 = 0,
    order_by = Array(String | Symbol).new,
    order_desc = false,
    **args
  )
    where = _where_query(**args)
    self._query_all(
      limit: limit,
      offset: offset,
      order_by: order_by,
      order_desc: order_desc,
      where: where,
    )
  end

  # :nodoc:
  def self._limit_query(limit : Int32 = 0, offset : Int32 = 0) : String
    if limit <= 0
      ""
    else
      String.build do |io|
        io << " LIMIT #{limit} "
        if offset > 0
          io << " OFFSET #{offset} "
        end
      end
    end
  end

  # :nodoc:
  def self._order_query(order_by = Array(String | Symbol).new, order_desc = false)
    if order_by.empty?
      ""
    else
      q = String.build do |io|
        io << " ORDER BY "
        order_by.each do |col|
          if col =~ /(.*)\s+desc$/i
            io << '`' << $1 << '`' << " DESC" << ','
          elsif col =~ /(.*)\s+asc$/i
            io << '`' << $1 << '`' << " ASC" << ','
          else
            io << '`' << col << '`' << ','
          end
        end
      end
      q = q.chomp(',')
      q += " DESC " if order_desc && !(/DESC$/i === q)
      q
    end
  end
end
