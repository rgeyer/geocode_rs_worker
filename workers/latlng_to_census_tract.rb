# Requires 'griffordson-georuby-extras' gem
# sudo gem install griffordson-georuby-extras

require 'yaml'
require 'rubygems'
require 'georuby-extras'

include GeoRuby::SimpleFeatures

shapesyaml = "../censustracts.yaml"
shapes = YAML::load_file(shapesyaml)

rings = []

shapes.each do |shp|
  ring = LinearRing.from_coordinates(shp[:vertices])
  rings << {:tract_id => shp[:tract_id], :ring => ring}
end

matchring = nil

rings.each do |ring|
  point = Point.from_coordinates([-119.877210,34.433827])
  if ring[:ring].fast_contains?(point)
    matchring = ring
  end
end

puts matchring.to_yaml