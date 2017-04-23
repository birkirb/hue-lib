require 'net/http'
require 'json'
require 'securerandom'

module Hue

  DEVICE_TYPE = 'hue-lib'
  DEFAULT_UDP_TIMEOUT = 5
  ERROR_DEFAULT_EXISTS = 'Default application already registered.'
  ERROR_NO_BRIDGE_FOUND = 'No bridge found.'

  def self.device_type
    DEVICE_TYPE
  end

  def self.one_time_uuid
    SecureRandom.hex(16)
  end

  def self.register_default
    if (Hue::Config::Application.default rescue nil)
      raise Hue::Error.new(ERROR_DEFAULT_EXISTS)
    else
      bridge_config = register_bridges.values.first # Assuming one bridge for now
      puts "Registering new app..."
      instance = Hue::Bridge.register(bridge_config.uri)
      app_config = Hue::Config::Application.new(bridge_config.id, instance.application_id)
      app_config.write
      instance
    end
  end

  def self.application
    application_config = Hue::Config::Application.default
    bridge_config = Hue::Config::Bridge.find(application_config.bridge_id)
    bridge_config ||= register_bridges[application_config.bridge_id]

    if bridge_config.nil?
      raise Error.new("Unable to find bridge: #{application_config.bridge_id}")
    end

    Hue::Bridge.new(application_config.id, bridge_config.uri)
  end

  def self.remove_default
    instance = application
    instance.unregister
    Hue::Config::Application.default.delete
    true
  end

  def self.discover
    bridges = Hash.new
    udp_discover(bridges)
    nupnp_discover(bridges)
    bridges
  end

  def self.udp_discover(bridges)
    Hue.logger.info("Bridge UDP Discovery")
    payload = <<-PAYLOAD
M-SEARCH * HTTP/1.1
ST: ssdp:all
MX: 10
MAN: ssdp:discover
HOST: 239.255.255.250:1900
    PAYLOAD
    broadcast_address = '239.255.255.250'
    port_number = 1900

    socket = UDPSocket.new(Socket::AF_INET)
    socket.send(payload, 0, broadcast_address, port_number)

    Timeout.timeout(DEFAULT_UDP_TIMEOUT, Hue::Error) do
      loop do
        message, (address_family, port, hostname, ip_add) = socket.recvfrom(1024)
        if message =~ /IpBridge/ && location = /LOCATION: (.*)$/.match(message)
          if uuid_match = /uuid:(.{36})/.match(message)
            # Assume this is Philips Hue for now.
            uuid = uuid_match.captures.first
            if bridges[uuid].nil?
              logger.info("Found bridge (#{hostname}:#{port}) with uuid: #{uuid}")
            end
            bridges[uuid] = "http://#{ip_add}/api"
          end
        else
          logger.debug("Found #{hostname}:#{port}: #{message}")
        end
      end
    end
  rescue Hue::Error => err
    Hue.logger.warn(err)
    logger.info("UDPSocket timed out.")
  end

  def self.nupnp_discover(bridges)
    if bridges.size > 0
      return
    end

    Hue.logger.info("Bridge NUPNP Discovery")
    response = Net::HTTP.get_response(URI("https://www.meethue.com/api/nupnp"))
    json = JSON.parse(response.body) rescue nil
    if !json.nil?
      json.each do |bridge|
        uuid = bridge['id']
        ip_add = bridge['internalipaddress']
        if !uuid.nil? && !ip_add.nil?
          bridges[uuid] = "http://#{ip_add}/api"
        end
      end
    end
  end

  def self.register_bridges
    bridges = self.discover
    if bridges.empty?
      raise Error.new(ERROR_NO_BRIDGE_FOUND)
    else
      bridges.inject(Hash.new) do |hash, (id, ip)|
        config = Hue::Config::Bridge.new(id, ip)
        config.write
        hash[id] = config
        hash
      end
    end
  end

  class Error < StandardError
    attr_accessor :original_error

    def initialize(message, original_error = nil)
      super(message)
      @original_error = original_error
    end

    def to_s
      if @original_error.nil?
        super
      else
        "#{super}\nCause: #{@original_error.to_s}"
      end
    end
  end

  module API
    class Error < ::Hue::Error
      def initialize(api_error)
        @type = api_error['type']
        @address = api_error['address']
        super(api_error['description'])
      end
    end
  end

  def self.logger
    if !defined?(@@logger)
      log_dir_path = File.join('/var', 'log', 'hue')
      begin
        FileUtils.mkdir_p(log_dir_path)
      rescue Errno::EACCES
        log_dir_path = File.join(ENV['HOME'], ".#{device_type}")
        FileUtils.mkdir_p(log_dir_path)
      end

      log_file_path = File.join(log_dir_path, 'hue-lib.log')
      log_file = File.new(log_file_path, File::WRONLY | File::APPEND | File::CREAT)
      @@logger = Logger.new(log_file)
      @@logger.level = Logger::INFO
    end

    @@logger
  end

  def self.percent_to_unit_interval(value)
    if percent = /(\d+)%/.match(value.to_s)
      percent.captures.first.to_i / 100.0
    else
      nil
    end
  end

end

require 'hue/config/abstract'
require 'hue/config/application'
require 'hue/config/bridge'
require 'hue/bridge'
require 'hue/colors'
require 'hue/bulb'
