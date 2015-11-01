#!/usr/bin/env ruby
$VERBOSE = nil 
#
#
# f5_node_initator - Script to join host to an existing F5 Pool using chef recipe
#

require 'rubygems'
require 'f5-icontrol'
require 'optparse'
require 'highline/import'

options = {:f5address => nil, :f5user => nil, :f5pass => nil, :pool_name => nil, :node_address => nil, :node_port => nil, :partition_name => nil}

parser = OptionParser.new do |opts|
        opts.banner = "Usage: f5_node_initiator.rb [options]"
        opts.on('-H', '--f5address f5address', "\tF5 IP Address") do |f5address|
                options[:f5address] = f5address;
        end
        opts.on('-u', '--f5user user', "\tF5 username") do |user|
                options[:f5user] = user;
        end
        opts.on('-p', '--f5pass password', "\tF5 password") do |password|
                options[:f5pass] = password;
        end
        opts.on('-n', '--pool_name pool', "\tPool Name") do |pool|
                options[:pool_name] = pool;
        end
        opts.on('-a', '--node_address nodeaddress', "\tNode Address") do |node_address|
                options[:node_address] = node_address;
        end
        opts.on('-t', '--node_port nodeport', "\tNode Port") do |node_port|
                options[:node_port] = node_port;
        end
        opts.on('-r', '--partition_name partition', "\tPartition Name") do |partition|
                options[:partition_name] = partition;
        end
        opts.on('-h', '--help', "\tDisplays Help") do
                puts opts
                exit
        end
end

# Parse arguments and enforce requirement list
begin
  parser.parse!
  mandatory = [:f5address, :f5user, :f5pass, :pool_name,:node_address,:node_port,:partition_name]
  missing = mandatory.select{ |param| options[param].nil? }
  if not missing.empty?
    puts "Missing options: #{missing.join(', ')}"
    puts parser
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s                                                           # Friendly output when parsing fails
  puts parser                                                            #
  exit                                                                   #
end                                                                      #

f5address = options[:f5address]
f5user = options[:f5user]
f5pass = options[:f5pass]
pool_name = [ options[:pool_name] ]
node_address = options[:node_address]
node_port = options[:node_port]
partition = options[:partition_name]

# temporary credential prompt
#f5pass = ask("Password: ") { |q| q.echo = false }

# Retrieve F5 interfaces for interacting with device
f5 = F5::IControl.new(f5address,f5user,f5pass,['System.Session','LocalLB.Pool']).get_interfaces

# Set Active Folder on device 
begin
        f5['System.Session'].set_active_folder("/#{partition}")
rescue SOAP::FaultError => error
        puts "There was an error setting active partition to " + partition + ". Please make sure the partition exists.\n"
        exit 1
end

# Access Virtual Server list
currentPoolMembers = f5['LocalLB.Pool'].get_member_v2(pool_name)
pool_members = f5['LocalLB.Pool'].get_member(pool_name)[0].collect do |pool_member|
  pool_member['address'] + ':' + pool_member['port'].to_s
end

# Check if node already exists in pool
unless pool_members.include?(node_address + ":" + node_port)
  # Member does not exist, join
  begin
    f5['LocalLB.Pool'].add_member(pool_name, [[{ 'address' => node_address, 'port' => node_port.to_i }]])
  rescue SOAP::FaultError => error
    puts "ERROR: There was an error adding host #{node_address} to pool #{pool_name} Please make sure the pool exists.\n"
    exit 1
  end
end
