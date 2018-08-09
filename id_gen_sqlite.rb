#!/usr/bin/env ruby

require 'time'
require 'optparse'
require 'sqlite3'

@db = './id_gen.db'
@timeout = 5 # Days
@range = [2, 6]

def load_data
    ids = Array.new(@range.last + 1 - @range.first, true)
  begin
    conn = SQLite3::Database.new "#{@db}"
    conn.execute "CREATE TABLE IF NOT EXISTS ActiveIds(IdNumber INT PRIMARY KEY NOT NULL, Description TEXT, Time TIMESTAMP NOT NULL)"
    res = conn.execute "SELECT IdNumber FROM ActiveIds"
    
    res.each do |row|
      ids[row[0].to_i - @range.first] = false
    end
  rescue SQLite3::Exception => e
    return -1
  ensure
    conn.close if conn
  end
  ids	
end

def gen_id 
  ids = load_data
  return -1 if ids == -1;
  return -1 unless ids.index(true)
  ids.index(true) + @range.first
end

def allocate(desc)  
  id = gen_id
  begin
    return -1 if id == -1
    conn = SQLite3::Database.open "#{@db}"
    time = Time.now.to_i
    conn.execute "INSERT INTO ActiveIds VALUES(#{id},'#{desc}',#{time})"
  rescue SQLite3::ConstraintException => e
    retry 
  rescue SQLite3::Exception => e
    return -1
  ensure
    conn.close if conn 
  end
  return id
end

def isActive(id)
  begin
    conn = SQLite3::Database.open "#{@db}"
    query = conn.get_first_value "SELECT IdNumber FROM ActiveIds WHERE IdNumber=#{id}"
  rescue SQLite3::Exception => e
    return -1
  ensure
    conn.close if conn
  end
  return 0
end

def release(id)
  return -1 if !isActive(id)
  begin
    conn = SQLite3::Database.open "#{@db}"
    conn.execute "DELETE FROM activeIds WHERE IdNumber=#{id}"
  rescue SQLite3::Exception => e
    return -1
  ensure
    conn.close if conn
  end
  return 1
end

def release_timeouts
  threshold = @timeout * 24 * 60 * 60
  now = Time.now.to_i
  begin
    conn = SQLite3::Database.open "#{@db}"
    conn.execute "DELETE FROM activeIds WHERE (#{now} - Time) > #{threshold} "
  rescue SQLite::Exception => e
    puts 'Exception occured'
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
rescue OptionParser::InvalidArgument, OptionParser::MissingArgument
  puts @parser.help
  exit
end

if @options[:allocate]
  release_timeouts
  puts allocate(@options[:Description])
  
else # free
  puts release(@options[:free])
  release_timeouts
end
