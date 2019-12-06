# frozen_string_literal: true

require "singleton"
require "active_support/core_ext/hash/indifferent_access"

module Nandi
  class Lockfile
    include Singleton

    def self.file_present?
      File.exist?(path)
    end

    def self.create
      return if file_present?

      File.write(path, {}.to_yaml)
    end

    def self.add(file_name:, source_digest:, compiled_digest:)
      load!

      instance.lockfile[file_name] = {
        source_digest: source_digest,
        compiled_digest: compiled_digest,
      }
    end

    def self.get(file_name)
      load!

      {
        source_digest: instance.lockfile.dig(file_name, :source_digest),
        compiled_digest: instance.lockfile.dig(file_name, :compiled_digest),
      }
    end

    def self.load!
      return instance.lockfile if instance.lockfile

      Nandi::Lockfile.create unless Nandi::Lockfile.file_present?

      instance.lockfile = YAML.safe_load(File.read(path)).with_indifferent_access
    end

    def self.persist!
      File.write(path, instance.lockfile.to_h.deep_stringify_keys.to_yaml)
    end

    def self.path
      Nandi.config.lockfile_directory.join(".nandilock.yml")
    end

    attr_accessor :lockfile
  end
end
