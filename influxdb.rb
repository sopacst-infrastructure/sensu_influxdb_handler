#
# Sensu extension for writing to InfluxDB
# I am not a ruby programmer...
#

gem 'influxdb', '>=0.2.0'
require 'influxdb'

#
# Sensu To Influxdb
#
module Sensu::Extension
  class SensuToInfluxDB < Handler
    def name
      'influxdb'
    end

    def definition
      {
        type: 'extension',
        name: 'influxdb'
      }
    end

    def description
      'Outputs metrics to InfluxDB'
    end

    def post_init(); end

    def stop
      yield
    end

    def run(event)

      # create an array? of configuration options.
      opts = @settings['influxdb'].each_with_object({}) do |(k, v), sym|
        sym[k.to_sym] = v
      end

      # turn the event data into a json blob.
      event = MultiJson.load(event)

      # connect to the database
      database = opts[:database]
      influxdb_data = InfluxDB::Client.new database, opts

      # build the data
      client_name = event[:client][:name]
      metric_name = event[:check][:name]
      metric_raw = event[:check][:output]

      data = []
      metric_raw.split("\n").each do |metric|
        m = metric.split
        next unless m.count == 3
        key = m[0].split('.', 2)[1]
        key.gsub!('.', '_')
        value = m[1].to_f
        time = m[2]
        # this stuff is likely unique to physics
        # substitute /disk/(servername)(number) with /disk/data(number)
        hn = m[0].split('.', 2)[0]
        key.gsub!("disk_#{hn}", "disk_data")
        # hardcode the key for tempagers
        # may redo this later
        if m[0].include? "tempager"
          key = "tempager_#{m[0].split('.', 3)[2]}"
        end
        # the unique stuff finishes here
        point = { series: key,
                  tags: { hostname: client_name, metric: metric_name },
                  values: { value: value },
                  timestamp: time
                }
        data.push(point)
      end

      # write the data
      influxdb_data.write_points(data)

      yield("InfluxDB: metrics updated.", 0)
    end

  end
end
