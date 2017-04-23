require 'socket'
require 'timeout'
require 'logger'

module Hue
  class Bridge

    public

    attr_reader :application_id, :bridge_uri

    def initialize(application_id, bridge_uri)
      @application_id = application_id
      @bridge_uri = bridge_uri
    end

    def status
      index(uri)
    end

    def add_lights
      create(uri('lights'))
    end

    def lights
      index(uri('lights'))
    end

    def light_names
      lights.map { |k,v| "#{k}. #{v['name']}" }.join("\n")
    end

    def config
      index(uri('config'))
    end

    def schedules
      index(uri('schedules'))
    end

    def bulbs
      @bulbs ||= lights.keys.map { |b| Bulb.new(self, b) }
    end

    # def remove_schedule(schedule_id)
    #   delete uri('schedules', schedule_id)
    #   puts "Removed schedule #{schedule_id}"
    # end

    # def remove_all_schedules
    #   ids = schedules.keys.map(&:to_i).sort.reverse
    #   puts "Removing #{ids.size} schedule#{'s' if ids.size != 1}..."
    #   ids.each{|x| remove_schedule x}
    # end

    def self.register(bridge_uri)
      instance = self.new("", bridge_uri)
      instance.register
      instance
    end

    def register
      response = create(URI.parse(bridge_uri), {"devicetype" => "#{Hue.device_type}@#{Socket.gethostname}"})
      if response.first.has_key?('success')
        @application_id = response.first['success']['username']
      end
    end

    def unregister
      delete(uri('config', 'whitelist', application_id))
    end

    def get_light(id)
      index(uri('lights', id))
    end

    def set_light(id, property)
      update(uri('lights', id), property)
    end

    def set_light_state(id, state)
      update(uri('lights', id, 'state'), state)
    end

    private

    def uri(*args)
      URI.parse([bridge_uri, application_id, args].flatten.reject { |x| x.to_s.strip == '' }.join('/'))
    end

    def index(url)
      receive(Net::HTTP::Get, url)
    end

    def update(url, settings = {})
      receive(Net::HTTP::Put, url, settings.to_json)
    end

    def delete(url, settings = {})
      receive(Net::HTTP::Delete, url, settings.to_json)
    end

    def create(url, settings = {})
      receive(Net::HTTP::Post, url, settings.to_json)
    end

    def receive(request_class, url, payload = nil)
      request = request_class.new(url.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = payload if payload
      Hue.logger.info("Sending #{payload.to_s if payload} to #{url.to_s}")
      response = nil
      begin
        http = Net::HTTP.new(url.host, url.port)
        http.open_timeout = 3  # Quick timeout on connection fail.
        http.read_timeout = 8 # Slower timeout on read fail, but way faster than the default.
        response = http.start { |http| http.request(request) }
      rescue => err
        Hue.logger.error(err.message)
        raise Hue::Error.new("Problem reaching bridge.", err)
      end

      if response && response.code.to_s != '200'
        Hue.logger.info("Error with response #{response.code} #{response.message}")
        raise Hue::Error.new("Unexpected response: #{response.code}, #{response.message}")
      else
        json = JSON.parse(response.body)
        Hue.logger.info("Response #{response.code} #{response.message}: #{json}")
        if json.is_a?(Array) && error = json.first['error']
          raise Hue::API::Error.new(error)
        else
          json
        end
      end
    end

  end
end
