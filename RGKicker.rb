class RGKicker
  def do_work(message_env, message)
    starttime = Time.now
    s3_downloaded_list = message_env[:s3_downloaded_list]
    conversion_type = message_env[:conversion_type]
    f = File.new('/mnt/rightgrid/img.log', 'a+')
    f.write "/usr/bin/ruby -d image_convert.rb -t #{conversion_type} -i #{s3_downloaded_list[s3_downloaded_list.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)')} -o #{message_env[:output_dir]}/#{File.basename(s3_downloaded_list[s3_downloaded_list.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)'))} \n"
    f.close
		puts `/usr/bin/ruby -d image_convert.rb -t #{conversion_type} -i #{s3_downloaded_list[s3_downloaded_list.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)')} -o #{message_env[:output_dir]}/#{File.basename(s3_downloaded_list[s3_downloaded_list.keys.first].gsub(/\(/, '\(').gsub(/\)/, '\)'))}`

    finishtime = Time.now
    rg_result=0
    if $?.exitstatus == 0
    	rg_result = 0
    else 
    	rg_result = "exception: image_convert ended with #{$?.exitstatus} status"
    end  

    result = {
      :result => rg_result,
      :id => message_env[:id],
      :audit_info => {
    		:serial => message_env[:serial],
    		:receive_message_timeout => message_env[:receive_message_timeout]
     	},
      :serial => message_env[:serial],
      :starttime => starttime,
      :finishtime => finishtime,
      :created_at => message_env[:created_at],
      :output => message_env[:ec2_instance_id]
     }
  end

end