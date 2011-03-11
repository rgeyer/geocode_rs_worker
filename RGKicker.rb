require 'yaml'
require 'placefinder'
require 'georuby-extras'

include GeoRuby::SimpleFeatures

class RGKicker
  def write_log(message, env)
    filepath = File.join(env[:log_dir], 'geo.log')
    timestamp = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S %Z")
    File.open(filepath,'a+') do |log|
      log.write("#{timestamp} - #{message}\n")
    end
  end

  def do_work(message_env, message)
    starttime         = Time.now
    rg_result         = 0
    lat               = nil
    lng               = nil
    census_tract_id   = nil

    write_log("GeoLocating address id #{message_env[:id]}", message_env)

    write_log("message_env: #{message_env.to_yaml}", message_env)
    write_log("message: #{message.to_yaml}", message_env)
    
    pf = Placefinder::Base.new(:api_key => message_env[:yahoo_api_key])
    georesult = pf.get(:q => message_env[:address])
    if georesult['ResultSet']['Error'] != "0"
      rg_result = "Did not geolocate address.  Message: #{georesult['ResultSet']['ErrorMessage']}"
      write_log(rg_result, message_env)
    else
      lat = georesult['ResultSet']['Result']['latitude']
      lng = georesult['ResultSet']['Result']['longitude']

      shapes = YAML::load_file(File.join(message_env[:s3_in], 'censustracts.yaml'))

      rings = []

      shapes.each do |shp|
        ring = LinearRing.from_coordinates(shp[:vertices])
        rings << {:tract_id => shp[:tract_id], :ring => ring}
      end

      rings.each do |ring|
        point = Point.from_coordinates([lng,lat])
        if ring[:ring].fast_contains?(point)
          census_tract_id = ring[:tract_id]
          break
        end
      end
    end


    finishtime = Time.now

    # Added the explicit return since it's not entirely obvious that this hash is returned
    return result = {
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
      :address => message_env[:address],
	  	:lat => "#{lat}",
	  	:lng => "#{lng}",
	  	:census_tract_id => "#{census_tract_id}"
     }
  end
end