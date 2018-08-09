#!/usr/bin/env ruby

require 'json'
require 'time'
require 'optparse'

@config = './cfg.json'
@timeout = 5 # Days
@range = [2, 6]

def load_data
  if File.file?(@config)
    JSON.parse(File.read(@config))
  else
    {
      'active_ids' => {}
    }
  end
end

def load_ids(data)
  ids = Array.new(@range.last + 1 - @range.first, true)
  data['active_ids'].each_key { |k| ids[k.to_i - @range.first] = false }
  ids
end

def allocate(desc)
  data = load_data
  ids = load_ids(data)
  return -1 unless ids.index(true)
  id = ids.index(true) + @range.first
  data['active_ids'][id] = {
    'desc' => desc,
    'time' => Time.now.to_i
  }
  save_json(data)
  id
end

def save_json(hash)
  File.open(@config, 'w') do |f|
    f.write(hash.to_json)
  end
end

def release(id)
  data = load_data
  return unless (@range.first..(@range.last)).cover?(id.to_i)
  data['active_ids'].delete(id.to_s)
  save_json(data)
end

def release_timeouts
  data = load_data
  threshold = @timeout * 24 * 60 * 60
  data['active_ids'].delete_if do |_k, v|
    (Time.now.to_i - v['time']).to_i > threshold
  end
  save_json(data)
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
  release(@options[:free])
  release_timeouts
end
