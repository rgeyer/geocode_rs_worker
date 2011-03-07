###################################################################
#
#  Copyright Rightscale.inc 2007-2010, all rights reserved
#
#	JobProducer Program
#	
#
####################################################################
require 'yaml'
require 'rubygems'
require 'right_aws'
require 'mysql'

# This stores data in the bucket and key(path)
def upload_file(bucket, key, data)
  bucket.put(key, data)
end

def enqueue_work_unit(queue, work_unit)
  queue.send_message(work_unit)
end

# Log messages to the lof file and stdout
def log_message(log_msg_txt)
  `logger -t jobproducer #{log_msg_txt}`
  puts log_msg_txt
end

# Load jobspec
jobyaml = "jobspec.yml"
jobspec = YAML::load_file(jobyaml)
log_message("Job Yaml File: #{jobyaml}")

# Get S3 
s3 = RightAws::S3.new(jobspec[:access_key_id], jobspec[:secret_access_key])
bucket = s3.bucket(jobspec[:bucket], false)
log_message("S3 Bucket: #{jobspec[:bucket]}")

# SQS Queues
sqs = RightAws::SqsGen2.new(jobspec[:access_key_id], jobspec[:secret_access_key])
inqueue = sqs.queue(jobspec[:inputqueue], false)
log_message("Input Queue: #{jobspec[:inputqueue]}")

##################################################################################
# 
# The logic for this demo program is as follows:
#
#     1) Read the local directory for .jpgs
#     2) Upload data to an S3 bucket/key
#	  3) Construct a work_unit
#	  4) Encode the work_unit with YAML to a message
#	  5) Enqueue the message
# 
##################################################################################
rrpid = $$
f_iterations = 0

my = Mysql::new("localhost", "root", "", "portu_list")

# This one grabs the whole enchilada, but for testing we'll do something a little different
#query = 'SELECT * FROM addr WHERE status != 2 AND `long` = 0 AND `lat` = 0 LIMIT 0,5000'

# The test query
query = 'SELECT * FROM addr WHERE status != 2 LIMIT 0,1000'

res = my.query(query)
res.each do |row|
	# Construct a Work_Unit
	# a work_unit can have any number of elements but must have the following 3 elements
	#   created_at
	#   s3_download
	#   work_name
	serialid  = "#{rrpid}_#{f_iterations}"
	puts "Generating Serial Id: #{serialid}"

#  sprintf('%s %s, %s, %s, %s',
#          	$person[STREET_NUM_IDX], $person[STREET_IDX], $person[CITY_IDX], $person[STATE_IDX], $person[ZIP_IDX]);

  address = "#{res['st_num']} #{res['street']}, #{res['city']}, #{res['state']}, #{res['zip']}"

	work_unit = {
	  :created_at => Time.now.utc.strftime('%Y-%m-%d %H:%M:%S %Z'),
	  :worker_name => 'RGKicker',
	  :id => res['id'],
	  :serial => serialid,
	  :address => address,
	  :lat => "",
	  :lng => "",
	  :census_tract_id => ""
	}

	# Encode a work_unit using YAML and place the resulting message in the :inputqueue 
	wu_yaml = work_unit.to_yaml
	sndmsg = enqueue_work_unit(inqueue, wu_yaml)
	
	# Send debug message to the logs
	log_message("Serial: #{serialid} MsgID: #{sndmsg.id} Queued to #{jobspec[:inputqueue]}")
end
my.close
