###################################################################
#
#  Copyright Rightscale.inc 2007-2010, all rights reserved
#
#	JobConsumer Program
#	
#
####################################################################
require 'rubygems'
require 'yaml'
require 'right_aws'
require 'uri'
require 'fileutils'
require 'net/smtp'
require '/var/spool/ec2/meta-data-cache.rb'
require '/var/spool/ec2/user-data.rb'
require 'optparse'

# Log messages to the lof file and stdout
def log_message(log_msg_txt)
  `logger -t jobproducer log_msg_txt`
  puts log_msg_txt
end

def download_result(bucket, key)
    bucket.get(key)
end

# this retrieves and deletes the next queued message
def dequeue_entry(queue)
   queue.pop
end
def enqueue_work_unit(queue, work_unit)
  queue.send_message(work_unit)
end

def send_email(from, from_alias, to, to_alias, subject, message)
	msg = <<END_OF_MESSAGE
From: #{from_alias} <#{from}>
To: #{to_alias} <#{to}>
Subject: #{subject}
Date: #{Time.now}
     

#{message}
END_OF_MESSAGE
	
	Net::SMTP.start('localhost') do |smtp|
		smtp.send_message msg, from, to
	end
end

log_message("Program Started")

# Load jobspec
jobyaml = "jobspec.yml"
jobspec = YAML::load_file(jobyaml)
log_message("Job Yaml File : #{jobyaml}")

# Get S3 Buckets
@s3 = RightAws::S3.new(jobspec[:access_key_id], jobspec[:secret_access_key])
bucket = @s3.bucket(jobspec[:bucket], false)
log_message("S3 Bucket: #{jobspec[:bucket]}")

# Get SQS Handles
sqs = RightAws::SqsGen2.new(jobspec[:access_key_id], jobspec[:secret_access_key])
@i_queue = sqs.queue(jobspec[:inputqueue], false)
@o_queue = sqs.queue(jobspec[:outputqueue], false)
@a_queue = sqs.queue(jobspec[:auditqueue], false)
@e_queue = sqs.queue(jobspec[:errorqueue], false)

log_message("Input Queue : #{jobspec[:inputqueue]} size=#{@i_queue.size()}")
log_message("Output Queue: #{jobspec[:outputqueue]} size=#{@o_queue.size()}")
log_message("Audit Queue : #{jobspec[:auditqueue]} size=#{@a_queue.size()}")
log_message("Error Queue : #{jobspec[:errorqueue]} size=#{@e_queue.size()}")

# count the number of messages still to process
num_msg_to_process  = @i_queue.size() + @o_queue.size() + @a_queue.size() + @e_queue.size() 
log_message("number of messages in queues is: #{num_msg_to_process}")
# Create output Dir
FileUtils.mkdir_p('output/')

@processed_files=0


def parse_output_queue(o_queue, sleeptime)
  while true do
  	while o_queue.size() > 0 do
	
  	  # Try to dequeue an output message	
  	  msg = dequeue_entry(o_queue)
  	  if msg != nil then
  			decodemsg = YAML.load(msg.body)
  			s3_upload = decodemsg["s3_upload"]
  			d_bucket=@s3.bucket(s3_upload[s3_upload.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)').split('/').first,false)
  			#d_key=s3_upload[s3_upload.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)').split('/')[1..-1].join('/')
  		  d_key=URI.encode(s3_upload[s3_upload.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)').gsub(s3_upload[s3_upload.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)').split('/').first,"").gsub('/out','out'))
  		  f=File.new('output/'+d_key.split('/').last,'w+')
  			f.write download_result(d_bucket,d_key)
  			f.close
  			log_message(decodemsg)
  			# 4. Some Debug Output
  			log_message("Output Processing: serial ID: #{decodemsg[:serial]} Msg ID: #{msg.id}")	
  			log_message(msg)
  			@processed_files += 1
  	  end
  	end
  	
  	sleep(sleeptime)
  	break if sleeptime == 0
  end
end

def parse_audit_queue(a_queue, sleeptime)
  while true do
  	while a_queue.size() > 0 do
  		#create audit file
  		if !File.exists? 'output/audit.csv'
  			f = File.new('output/audit.csv','a+')
  			f.write "serial,result_item_id,secs_to_work,secs_to_download,secs_to_upload\n"
  			f.close
  		end
  	  # Try to dequeue an audit message	
  	  a_msg = dequeue_entry(a_queue)
  	  if a_msg != nil then
    	  #  1. Decode msg
    		decodemsg = YAML.load(a_msg.body)
    		f=File.new('output/audit.csv','a+')
    		f.write "#{decodemsg[:audit_info][:serial]},#{decodemsg[:result_item_id]},#{decodemsg[:secs_to_work]},#{decodemsg[:secs_to_download]},#{decodemsg[:secs_to_upload]}\n"
    		f.close
    		log_message(decodemsg)
	
    	  #  2. For example, update a central DB with statistics
    		#   +++ In this example, write data to a .csv file
		 	 
    		#  3. Some Debug Output
    		log_message("Audit Queue Processing: Msg ID: #{a_msg.id}")
    		log_message(a_msg)
    	  @processed_files += 1
  		end
  	end
  	
		sleep(sleeptime)
  	break if sleeptime == 0
  end
end

def parse_error_queue(e_queue, sleeptime)
  while true do
  	while e_queue.size() > 0 do 
  	  # Try to dequeue an error message	
  	  e_msg = dequeue_entry(e_queue)
  	  if e_msg != nil then
    		decodemsg = YAML.load(e_msg.body)
    		log_message("Error Queue Processing: serial ID: #{decodemsg[:serial]} Msg ID: #{e_msg.id}")	
    		log_message(decodemsg)
    		orig_msg=YAML.load(decodemsg["message"])
    	  orig_msg[:conversion_type]="sep"
    	  sndmsg = enqueue_work_unit(@i_queue, YAML.dump(orig_msg))
   	  end
  	end
  	
		sleep(sleeptime)
  	break if sleeptime == 0
  end
end

def parse_all_queues(options)
	parse_audit_queue(@a_queue,options[:sleeptime])
	parse_error_queue(@e_queue,options[:sleeptime])
	parse_output_queue(@o_queue,options[:sleeptime])
end
options = {}

optparse = OptionParser.new do |opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: jobconsumer.rb -q queue_type(audit,error,output) -t sleeptime  -e email_address..."
  # Define the options, and what they do
  options[:queue_type] = 'all'
  opts.on( '-q', '--queue_type TYPE', 'Type of queue(audit,error,output)' ) do |type|
    options[:queue_type] = type.downcase.chomp
  end
  options[:sleeptime] = 0
  opts.on( '-t', '--sleeptime seconds', 'time between queue runs' ) do |time|
    options[:sleeptime] = time.to_i
  end
  options[:to_email] = 'root@localhost'
  opts.on( '-e', '--email email_address', 'Email Address to send report to' ) do |to_email|
    options[:to_email] = to_email.to_s
  end
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

begin
	optparse.parse!
	rescue Exception => e
  STDERR.puts e 
  STDERR.puts optparse
  exit(-1) 
end

case options[:queue_type]
	when "audit"; parse_audit_queue(@a_queue,options[:sleeptime])
	when "error"; parse_error_queue(@e_queue,options[:sleeptime])
	when "output"; parse_output_queue(@o_queue,options[:sleeptime])
	else; parse_all_queues(options)
end

if @processed_files > 0 && options[:to_email]
	puts "Emailing Report to #{options[:to_email]}"
	email_msg = <<-EOF
	You can view your processed files at http://#{ENV['EC2_PUBLIC_HOSTNAME']}/rightgrid
	EOF
	send_email("root@#{ENV['EC2_PUBLIC_HOSTNAME']}", "root@#{ENV['EC2_PUBLIC_HOSTNAME']}", "#{options[:to_email]}", "#{options[:to_email]}", "Files Processed By RightGrid", email_msg)
end
