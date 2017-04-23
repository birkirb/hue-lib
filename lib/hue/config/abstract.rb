require 'yaml'
require 'fileutils'

module Hue
  module Config
    class NotFound < Hue::Error; end;

    class Abstract
      public

      attr_reader :path, :name

      def initialize(name, path)
        @path = path
        @name = name
        self.class.setup_file_path(self.path)
      end

      def write(overwrite_existing_key = false)
        yaml = YAML.load_file(self.path) rescue nil
        yaml ||= Hash.new

        if yaml.key?(name) && !overwrite_existing_key
          raise "Key named '#{name}' already exists in config file '#{self.path}'.\nPlease remove it before creating a new one with the same name."
        else
          add_self_to_yaml(yaml)
          dump_yaml(yaml)
        end
      end

      def delete
        yaml = YAML.load_file(self.path) rescue Hash::New

        if yaml.key?(name)
          yaml.delete(name)
        end

        dump_yaml(yaml)
      end

      def ==(rhs)
        lhs = self

        lhs.class == rhs.class && lhs.name == rhs.name
      end

      private

      def add_self_to_yaml(yaml)
        yaml[name] = {}
      end

      def dump_yaml(yaml)
        File.open(self.path, 'w+' ) do |out|
          YAML.dump(yaml, out)
        end
      end

      def self.setup_file_path(path)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      end

      def self.read_file(config_file)
        begin
          YAML.load_file(config_file)
        rescue => err
          raise Error.new("Failed to read configuration file", err)
        end
      end

    end
  end
end
