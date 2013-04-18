require 'spec_helper.rb'

describe Hue::Config::Bridge do

  mock_bridge_config_path

  after(:all) do
    create_test_bridge_config
  end

  it 'should report the config file location' do
    described_class.file_path.should == TEST_CONFIG_BRIDGE_PATH
  end

  it 'should find existing bridges given an id' do
    found = described_class.find(TEST_BRIDGE_UUID)
    found.id.should == TEST_BRIDGE_UUID
    found.uri.should == TEST_BRIDGE_URI

    described_class.find('something').should be_nil
  end

  context 'given an new config' do
    uuid = Hue.one_time_uuid
    uri = 'http://someip/api'
    config = described_class.new(uuid, uri)

    it 'should report the values' do
      config.name == uuid
      config.id == uuid
      config.uri == uri
    end
  end

end
