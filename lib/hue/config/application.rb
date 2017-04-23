module Hue
  module Config
    class Application < Abstract

      STRING_BRIDGE_ID = 'bridge_id'
      STRING_DEFAULT = 'default'
      STRING_ID = 'id'

      def self.file_path
        File.join(ENV['HOME'], ".#{Hue.device_type}", 'applications.yml')
      end

      def self.default
        named(STRING_DEFAULT)
      end

      def self.named(name)
        begin
          yaml = read_file(file_path)
        rescue => err
          Hue.logger.error(err)
        end

        if yaml && named_yaml = yaml[name]
          new(named_yaml[STRING_BRIDGE_ID], named_yaml[STRING_ID], name)
        else
          raise NotFound.new("Config named '#{name}' not found.")
        end
      end

      public

      attr_reader :bridge_id, :id, :name

      def initialize(bridge_id, id, name = STRING_DEFAULT, path = self.class.file_path)
        super(name, path)
        @bridge_id = bridge_id
        @id = id
      end

      def ==(rhs)
        super(rhs) &&
          self.bridge_id == rhs.bridge_id &&
          self.id == rhs.id
      end

      private

      def add_self_to_yaml(yaml)
        key = self.name.dup.force_encoding('ASCII') # Avoid binary encoded YAML
        bridge = bridge_id.dup.force_encoding('ASCII')
        yaml[key] = {
          STRING_ID => id.force_encoding('ASCII'),
          STRING_BRIDGE_ID => bridge,
        }
      end

    end
  end
end
