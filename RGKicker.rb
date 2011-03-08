class RGKicker
  def do_work(message_env, message)
    starttime = Time.now
    s3_downloaded_ist = message_env[:s3_downloaded_list]
    
    f = File.new('/mnt/rightgrid/img.log', 'a+')
    f.write "/usr/bin/ruby -d geocode.rb -k \"#{message_env[:yahoo_api_key]}\" -a \"#{message_env[:address]}\"\n"
    f.close
		lat_lng=`"/usr/bin/ruby -d geocode.rb -k "#{message_env[:yahoo_api_key]}' -a "#{message_env[:address]}"`.split(',')
    lat = lat_lng[0]
    lng = lat_lng[1]

		f = File.new('/mnt/rightgrid/img.log', 'a+')
    f.write "/usr/bin/ruby -d latlng_to_census_tract.rb -lat #{lat} -lng #{lng}"
    f.close
    census_tract_id=`/usr/bin/ruby -d census.rb -lat #{lat} -lng #{lng}`

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
      :address => res[1],
	  	:lat => "#{lat}",
	  	:lng => "#{lng}",
	  	:census_tract_id => "#{census_tract_id}"
     }
  end
end