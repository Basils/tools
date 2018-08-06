#!/usr/bin/env ruby

require 'json'
require 'time'
require 'optparse'

@CONFIG = "./cfg.json"
@timeout = 5 # Days
@range = [2, 6]
	 
def load_data
	if File.file?(@CONFIG)
		data = JSON.parse(File.read(@CONFIG))
	else
		data = {
				"active_ids" => Hash.new				
		}
	end
	return data
end

def allocate(desc)
	data=load_data
	ids = Array.new(@range.last+1 - @range.first ,true)
	data['active_ids'].each { |k,v| ids[k.to_i-@range.first] = false }
	if !ids.index(true)
		return -1
	end
	id = ids.index(true) + @range.first
	data['active_ids'][id] = {
				"desc" => desc,
				 "time" => Time.now.to_i
	}
	save_json(data) 
	return id
	
end

def save_json(hash)
	File.open(@CONFIG,"w") do |f|
		f.write(hash.to_json)
	end
end

def release(id)
	data=load_data()
	if (!(@range.first..(@range.last)).include?(id.to_i))
		return;
	end
	data['active_ids'].delete(id.to_s)
	save_json(data)
end
 
def release_timeouts()
	data=load_data()
	if(data['active_ids'].empty?)
		return
	end
	now = Time.now.to_i
	data['active_ids'].delete_if {|k,v| (now - v['time']).to_i > (@timeout *24 * 60*60)}
	save_json(data)
end


#MAIN
@options = {}
ARGV << '-h' if ARGV.empty?
@parser = OptionParser.new do |opts|
	opts.banner = "Usage: id_gen.rb [option]"
	opts.on('-a', '--allocate' , "Id Allocate" ) do 
		if(@options[:free])
			puts opts
			exit
		end
		@options[:allocate] = true
	end
	
	opts.on('-f' , '--free ID', Integer, "Free allocation") do |f|
		if(@options[:allocate])
			puts opts
			exit
		end
		@options[:free] = f
	end
	opts.on('-d', '--description [string]', String, "Description") do |d|
		@options[:Description] = d
	end	
	opts.on('-h', '--help' , 'Show this message') do 
		puts opts
		exit
	end
end
begin
	@parser.parse!
rescue OptionParser::InvalidArgument , OptionParser::MissingArgument
	puts @parser.help
	exit
end
if(@options[:allocate])
	release_timeouts
	puts allocate(@options[:Description])
else #free
	release(@options[:free])
	release_timeouts
end
