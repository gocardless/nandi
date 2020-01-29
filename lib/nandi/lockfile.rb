# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

module Nandi
  class Lockfile
    class << self
      def file_present?
        File.exist?(path)
      end

      def create!
        return if file_present?

        File.write(path, {}.to_yaml)
      end

      def add(file_name:, source_digest:, compiled_digest:)
        load!

        lockfile[file_name] = {
          source_digest: source_digest,
          compiled_digest: compiled_digest,
        }
      end

      def get(file_name)
        load!

        {
          source_digest: lockfile.dig(file_name, :source_digest),
          compiled_digest: lockfile.dig(file_name, :compiled_digest),
        }
      end

      def load!
        return lockfile if lockfile

        Nandi::Lockfile.create! unless Nandi::Lockfile.file_present?

        @lockfile = YAML.safe_load(File.read(path)).with_indifferent_access
      end

      def persist!
        File.write(path, lockfile.to_h.deep_stringify_keys.to_yaml)
      end

      def path
        Nandi.config.lockfile_directory.join(".nandilock.yml")
      end

      attr_accessor :lockfile
    end
  end
end
