require 'spec_helper.rb'

describe Hue::Bridge do

  context 'when instantiated' do
    bridge = test_bridge

    it 'should report the status' do
      with_fake_request
      bridge.status.should == api_reply(:get_success)
    end

    it 'should report errors' do
      with_fake_request(:lights, :unauthorized)
      lambda do
        bridge.lights
      end.should raise_error(Hue::API::Error, 'unauthorized user')
    end

    it 'should report the available lights' do
      with_fake_request(:lights)
      bridge.lights.should == api_reply(:lights)
    end

    it 'should report a simple string of light names' do
      with_fake_request(:lights)
      bridge.light_names.should == "1. Dining\n2. Bedroom Far\n3. Bedroom Near"
    end

    it 'should report the bridge config' do
      with_fake_request(:config)
      bridge.config.should == api_reply(:config)
    end

    it 'should report the light schedules' do
      with_fake_request(:schedules)
      bridge.schedules.should == api_reply(:schedules)
    end

    it 'should return instance of all the bulbs' do
      with_fake_request(:lights)
      bulbs = bridge.bulbs
      bulbs.size.should == 3
      bulbs.each do |bulb|
        bulb.should be_a(Hue::Bulb)
      end
    end

    it 'should allow unregistering an existing config' do
      with_fake_delete("config/whitelist/#{TEST_APPLICATION_UUID}")
      bridge.unregister
    end

    it 'should allow scanning for new lights' do
      with_fake_post("#{TEST_APPLICATION_UUID}/lights")
      bridge.add_lights
    end
  end

  context 'when instantiated with a new config' do
    new_id = 'new_test_id'
    bridge = described_class.new(new_id, TEST_BRIDGE_URI)

    it 'should allow registering the new config' do
      mock_socket_hostname
      with_fake_post(nil, {:devicetype => "hue-lib@hostname"})
      bridge.register
    end
  end

end
