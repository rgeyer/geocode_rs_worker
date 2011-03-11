# Requires 'griffordson-georuby-extras' gem
# sudo gem install griffordson-georuby-extras

require 'yaml'
require 'rubygems'
require 'optparse'
require 'georuby-extras'

include GeoRuby::SimpleFeatures

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: latlng_to_census_tract -lat latitude -lng longitude -tf /path/to/tract_shapes.yaml ..."

  options[:lat]
  opts.on('-t', '--latitude latitude', 'The latitude of the coordinates to locate within a census tract') do |lat|
    options[:lat] = lat
  end

  options[:lng]
  opts.on('-g', '--longitude longitude', 'The longitude of the coordinates to locate within a census tract') do |lng|
    options[:lng] = lng
  end

  options[:shapefile]
  opts.on('-f', '--tracts_file /path/to/tract_shapes.yaml') do |shapefile|
    options[:shapefile] = shapefile
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  raise "Coordinates are required" unless options[:lat] && options[:lng]
  raise "A path to a shapefile is required" unless options[:shapefile]
rescue Exception => e
  STDERR.puts e
  STDERR.puts optparse
  exit(-1)
end

shapes = YAML::load_file(options[:shapefile])

rings = []

shapes.each do |shp|
  ring = LinearRing.from_coordinates(shp[:vertices])
  rings << {:tract_id => shp[:tract_id], :ring => ring}
end

matchring = nil

rings.each do |ring|
  point = Point.from_coordinates([options[:lng],options[:lat]])
  if ring[:ring].fast_contains?(point)
    matchring = ring
  end
end

# TODO: We're pretty much assuming success with the provided coords and putting the result down for stdout.
# Should we try harder to report errors?
puts matchring[:tract_id]