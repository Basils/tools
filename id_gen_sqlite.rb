#!/usr/bin/env ruby

require 'time'
require 'optparse'
require 'sqlite3'

@db = './id_gen.db'
@timeout = 5 # Days
@range = [2, 6]

def db_get_ids
  conn = SQLite3::Database.new @db.to_s
  conn.execute 'CREATE TABLE IF NOT EXISTS ActiveIds(
                UserKey INTEGER PRIMARY KEY AUTOINCREMENT,
                IdNumber INTNTEGER NOT NULL,
                Description TEXT,
                Time TIMESTAMP NOT NULL
);'
  res = conn.execute 'SELECT IdNumber FROM ActiveIds'
  [conn, res]
end

def load_data(array)
  conn, res = db_get_ids
  res.each do |row|
    array[row[0].to_i - @range.first] = false
  end
rescue SQLite3::Exception
  return -1
ensure
  conn.close if conn
end

def gen_id
  ids = Array.new(@range.last + 1 - @range.first, true)
  load_data(ids)
  return -1 if ids == -1
  return -1 unless ids.index(true)
  return ids.index(true) + @range.first
end

def db_gen_store(desc, time)
  id = gen_id
  return -1 if id == -1
  conn = SQLite3::Database.open @db.to_s
  conn.execute "INSERT INTO ActiveIds VALUES(null,#{id},'#{desc}',#{time})"
  key = conn.execute "SELECT UserKey FROM ActiveIds WHERE IdNumber=#{id}"
rescue SQLite3::ConstraintException
  retry
ensure
  conn.close if conn
  return [id, key[0][0]]
end

def allocate(desc)
  time = Time.now.to_i
  return db_gen_store(desc, time)
rescue SQLite3::Exception => e
  puts e
  return -1
end

def active(id)
  begin
    conn = SQLite3::Database.open @db.to_s
    return 0 unless conn.get_first_value "SELECT IdNumber FROM ActiveIds
                                          WHERE IdNumber=#{id}"
  rescue SQLite3::Exception
    return -1
  ensure
    conn.close if conn
  end
  1
end

def release(id, key)
  return -1 unless active(id).zero?
  begin
    conn = SQLite3::Database.open @db.to_s
    conn.execute "DELETE FROM ActiveIds WHERE IdNumber=#{id} AND UserKey=#{key}"
  rescue SQLite3::Exception
    return -1
  ensure
    conn.close if conn
  end
  1
end

def release_timeouts
  threshold = @timeout * 24 * 60 * 60
  now = Time.now.to_i
  begin
    conn = SQLite3::Database.open @db.to_s
    conn.execute "DELETE FROM ActiveIds WHERE (#{now} - Time) > #{threshold}"
  rescue SQLite3::Exception => e
    puts e
  ensure
    conn.close if conn
  end
end

# MAIN

@options = {}
ARGV << '-h' if ARGV.empty?
@parser = OptionParser.new do |opts|
  opts.banner = 'Usage: id_gen.rb [option]'
  opts.on('-a', '--allocate', 'Id Allocate') do
    if @options[:free]
      puts opts
      exit
    end
    @options[:allocate] = true
  end

  opts.on('-f', '--free ID', Integer, 'Free allocation') do |f|
    if @options[:allocate]
      puts opts
      exit
    end
    @options[:free] = f
  end
  opts.on('-k', '--key KEY', Integer, 'UserKey') do |k|
    @options[:key] = k
  end
  opts.on('-d', '--description [string]', String, 'Description') do |d|
    @options[:Description] = d
  end
  opts.on('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
end
begin
  @parser.parse!
  raise OptionParser::MissingArgument if @options[:free] && !@options[:key]
rescue OptionParser::InvalidArgument, OptionParser::MissingArgument
  puts @parser.help
  exit
end

if @options[:allocate]
  release_timeouts
  id,key = allocate(@options[:Description])
  puts '{' + '"ID" : ' + "#{id}" + ', "Key" : ' + "#{key}" + '}'
else # free
  puts release(@options[:free], @options[:key])
  release_timeouts
end
