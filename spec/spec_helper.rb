require 'hue'
require 'webmock'
require 'webmock/rspec'
require 'mocha'

WebMock.disable_net_connect!

# GENERAL

def join_paths(*paths)
  File.join(paths.delete_if { |entry| entry.nil? || entry.empty? })
end

def with_stdout(expected_output, &block)
  original_stdout = $stdout
  new_stdout = StringIO.new
  begin
    $stdout = new_stdout
    yield
    new_stdout.seek(0)
    output = new_stdout.read
    output.should match(expected_output)
  ensure
    new_stdout.close
    $stdout = original_stdout
  end
end

def silence_warnings
  begin
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end
end

SPEC_DIR = File.dirname(__FILE__)
Hue.logger.level = Logger::DEBUG

silence_warnings do
  Hue.const_set(:DEFAULT_UDP_TIMEOUT, 0.01)
end

# APPLICATION CONFIG

EMPTY_CONFIG_FILE = File.join(SPEC_DIR, 'config', 'empty.yml')
TEST_CONFIG_APPLICATION_PATH = File.join(SPEC_DIR, 'config', 'applications.yml')
TEST_CONFIG_APPLICATION = YAML.load_file(TEST_CONFIG_APPLICATION_PATH)
TEST_JSON_DATA_PATH = File.join(SPEC_DIR, 'json')

def create_test_application_config(path = TEST_CONFIG_APPLICATION_PATH)
  File.open(path, 'w' ) do |out|
    YAML.dump(TEST_CONFIG_APPLICATION, out)
  end
end

def mock_application_config_path
  Hue::Config::Application.stubs(:file_path).returns(TEST_CONFIG_APPLICATION_PATH)
end

def with_temp_config_path(write_config = false)
  temp_config_path = File.join(SPEC_DIR, 'config', 'temp')
  FileUtils.mkdir_p(temp_config_path)
  temp_config = File.join(temp_config_path, 'applications.yml')
  if write_config
    create_test_application_config(temp_config)
  end
  Hue::Config::Application.expects(:file_path).at_least_once.returns(temp_config)

  begin
    yield
  ensure
    FileUtils.rm_f(temp_config)
    mock_bridge_config_path
  end
end

# BRIDGE CONFIG

TEST_CONFIG_BRIDGE_PATH = File.join(SPEC_DIR, 'config', 'bridges.yml')
TEST_BRIDGE_UUID = 'bc6be180-4c57-0130-8d8f-0018de9ecdd0'
TEST_CONFIG_BRIDGE = YAML.load_file(TEST_CONFIG_BRIDGE_PATH)

def create_test_bridge_config
  File.open(TEST_CONFIG_BRIDGE_PATH, 'w' ) do |out|
    YAML.dump(TEST_CONFIG_BRIDGE, out)
  end
end

def mock_bridge_config_path
  Hue::Config::Bridge.stubs(:file_path).returns(TEST_CONFIG_BRIDGE_PATH)
end

# HUE - DISCOVERY

TEST_UDP_BRIDGE_UUID = '09230030-4c1e-0130-8d83-0018de9ecdd0'
TEST_UDP_BRIDGE_HOSTNAME = 'upd-host'
TEST_UDP_BRIDGE_URI = "http://#{TEST_UDP_BRIDGE_HOSTNAME}/api"

def mock_udp_replies(uuid = TEST_UDP_BRIDGE_UUID, hostname = TEST_UDP_BRIDGE_HOSTNAME)
  reply = ["HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=100\r\nEXT:\r\nLOCATION: http://127.0.0.1:80/description.xml\r\nSERVER: FreeRTOS/6.0.5, UPnP/1.0, IpBridge/0.1\r\nST: upnp:rootdevice\r\nUSN: uuid:#{uuid}::upnp:rootdevice\r\n\r\n", ["AF_INET", 1900, "127.0.0.1", hostname]]

  socket = Object.new
  socket.stubs(:send).returns(nil)
  socket.stubs(:recvfrom).returns(reply)
  UDPSocket.stubs(:new).returns(socket)
end

def mock_udp_no_reply
  socket = Object.new
  socket.stubs(:send).returns(nil)
  socket.instance_eval do
    def recvfrom(args)
      while(true) do
        # Waiting for timeout.
      end
    end
  end
  UDPSocket.stubs(:new).returns(socket)
end

def mock_nupnp_empty_reply
  stub_request(:get, "https://www.meethue.com/api/nupnp").
    with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.meethue.com', 'User-Agent'=>'Ruby'}).
    to_return(:status => 200, :body => "", :headers => {})
end

# BRIDGE - API CALLS

TEST_BRIDGE_URI = 'http://localhost/api'
TEST_APPLICATION_UUID = 'application_uuid'

def test_bridge
  Hue::Bridge.new(TEST_APPLICATION_UUID, TEST_BRIDGE_URI)
end

def api_reply_json(named)
  file_name = File.join(TEST_JSON_DATA_PATH, named.to_s + '.json')
  json = File.read(file_name)
  json
end

def api_reply(named)
  JSON.parse(api_reply_json(named))
end

def with_fake_request(named = nil, body_name = nil)
  body_name ||= (named.nil? ? 'get_success' : named)
  stub_request(:get, join_paths(TEST_BRIDGE_URI, TEST_APPLICATION_UUID, named.to_s)).
    to_return(:status => 200, :body => api_reply_json(body_name), :headers => {})
end

def with_fake_update(named, put_body = {})
  stub = stub_request(:put, "#{TEST_BRIDGE_URI}/#{TEST_APPLICATION_UUID}/#{named.to_s}").
    with(:body => put_body.to_json).
    to_return(:status => 200, :body => api_reply_json(:put_success), :headers => {})

  if block_given?
    yield
    stub.should have_been_requested
  end
end

def with_fake_post(named, post_body = {}, post_reply_name = 'post_success', uri = TEST_BRIDGE_URI)
  stub = stub_request(:post, join_paths(uri, named))
  stub.with(:body => post_body.to_json) unless post_body.empty?
  stub.to_return(:status => 200, :body => api_reply_json(join_paths(named, post_reply_name)), :headers => {})

  if block_given?
    yield
    stub.should have_been_requested
  end
end

def with_fake_delete(named, delete_reply = 'delete_success')
  stub = stub_request(:delete, "#{TEST_BRIDGE_URI}/#{TEST_APPLICATION_UUID}/#{named.to_s}").
    to_return(:status => 200, :body => api_reply_json(join_paths(named, delete_reply)), :headers => {})

  if block_given?
    yield
    stub.should have_been_requested
  end
end

def mock_socket_hostname
  Socket.stubs(:gethostname).returns("hostname")
end
