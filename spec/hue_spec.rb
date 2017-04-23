require 'spec_helper.rb'

describe Hue do
  mock_application_config_path
  mock_bridge_config_path

  after(:each) do
    create_test_bridge_config
  end

  before(:each) do
    mock_udp_replies
  end

  it 'should report the device type as itself' do
    described_class.device_type.should == described_class::DEVICE_TYPE
  end

  it 'should return the default application' do
    described_class.application.should be_a(described_class::Bridge)
  end

  context 'when discovering a bridge on the network' do
    it 'should return a list discovered bridges' do
      bridges = Hue.discover
      bridges.should == {TEST_UDP_BRIDGE_UUID => TEST_UDP_BRIDGE_URI}
    end

    it 'should allow registering of discovered bridges' do
      Hue::Config::Bridge.find(TEST_UDP_BRIDGE_UUID).should be_nil
      registered = Hue.register_bridges
      new_bridge = registered[TEST_UDP_BRIDGE_UUID]
      new_bridge.id.should == TEST_UDP_BRIDGE_UUID
      new_bridge.uri.should == TEST_UDP_BRIDGE_URI
    end
  end

  context 'when attempting discover without a bridge on the network' do
    before(:each) do
      mock_udp_no_reply
      mock_nupnp_empty_reply
    end

    it 'should return an empty list of bridges' do
      bridges = Hue.discover
      bridges.should == {}
    end
  end

  context 'after discovering bridges' do
    before(:each) do
      mock_udp_replies(TEST_BRIDGE_UUID, 'new_host')
    end

    it 'should update already registered bridges' do
      bridge = Hue::Config::Bridge.find(TEST_BRIDGE_UUID)
      bridge.should_not be_nil

      registered = Hue.register_bridges

      updated_bridge = registered[TEST_BRIDGE_UUID]
      updated_bridge.id.should == TEST_BRIDGE_UUID
      updated_bridge.uri.should_not == bridge.uri
    end
  end

  context 'when registering or un-registering the application' do
    it 'should throw and error if the default already exists' do
      lambda do
        described_class.register_default
      end.should raise_error(described_class::Error, described_class::ERROR_DEFAULT_EXISTS)
    end

    it 'should allow a new default if one doesn\'t exist' do
      with_temp_config_path do
        with_fake_post(nil, {}, 'post_success', TEST_UDP_BRIDGE_URI)
        with_stdout(/Registering new app...$/) do
          described_class.register_default
        end
      end
    end

    it 'should allow un-registering the default' do
      with_temp_config_path(true) do
        with_fake_delete("config/whitelist/#{TEST_APPLICATION_UUID}")
        described_class.remove_default
      end
    end
  end

  context 'contains some utility methods' do
    it '#percent_to_unit_interval should convert a string with percent to a unit interval' do
      described_class.percent_to_unit_interval('1%').should == 0.01
      described_class.percent_to_unit_interval('10%').should == 0.1
      described_class.percent_to_unit_interval('100%').should == 1.00
    end
  end

end
