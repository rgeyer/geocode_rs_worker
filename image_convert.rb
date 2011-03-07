require 'rubygems'
require 'optparse'

def convert_bw(input_file,output_file)
	puts "converting bw"
	puts "convert #{input_file} -charcoal 1 #{output_file}"
	puts `convert #{input_file} -charcoal 1 #{output_file}`
end

def convert_sepia(input_file,output_file)
	puts `convert #{input_file} -sepia-tone 1 #{output_file}`
end

def convert_red(input_file, output_file)
	 puts "converting red"
	 exit 1
end

options = {}

optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: image_convert.rb -t conversion_type -i input_file -o output_file ..."
  # Define the options, and what they do
  options[:conversion_type]
  opts.on( '-t', '--conversion_type TYPE', 'Type of conversion(BW,SEP,RED)' ) do |type|
    options[:conversion_type] = type.downcase.chomp
  end
  options[:input_file] = nil
  opts.on( '-i', '--input_file FILE', 'Image File to be converted' ) do |input_file|
    options[:input_file] = input_file
  end
  options[:output_file] = nil
  opts.on( '-o', '--output_file FILE', 'Output File of Converted image' ) do|output_file|
    options[:output_file] = output_file
  end
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
begin
	optparse.parse!
	raise "Input is required" unless options[:input_file]
	raise "conversion type is required " unless options[:conversion_type]
	rescue Exception => e
  STDERR.puts e 
  STDERR.puts optparse
  exit(-1) 
end

input_filename = options[:input_file]
#output_filename = input_filename.gsub(/#{File.extname(input_filename)}/, ".png") unless options[:output_file]
output_filename = options[:output_file]
case options[:conversion_type].to_s
  when "bw"; convert_bw(input_filename,output_filename)
 	when "sep"; convert_sepia(input_filename,output_filename)
  when "red"; convert_red(input_filename,output_filename)
  else; puts "Conversion type not specified, exiting"; exit 1
end