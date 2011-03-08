# Requires 'placefinder' gem
# sudo gem install placefinder

require 'rubygems'
require 'optparse'
require 'placefinder'

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: geocode -k yahoo_api_key -a address ..."

  options[:address]
  opts.on('-a', '--address ADDRESS', 'Full street address in the form - Street # Street, City, State, Zip') do |addr|
    options[:address] = addr
  end

  options[:api_key]
  opts.on('-k', '--yahoo_api_key', 'A Yahoo! Application API Key') do |key|
    options[:api_key] = key
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  raise "An address is required" unless options[:address]
  raise "A Yahoo! Application API Key is required" unless options[:api_key]
rescue Exception => e
  STDERR.puts e
  STDERR.puts optparse
  exit(-1)
end

pf = Placefinder::Base.new(:api_key => options[:api_key])
georesult = pf.get :q => options[:address]

# TODO: We're pretty much assuming success with the provided address and putting the result down for stdout.
# Should we try harder to report errors?
puts "#{georesult['ResultSet']['Result']['latitude']},#{georesult['ResultSet']['Result']['longitude']}"