# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "digest"

module Nandi
  class Lockfile
    attr_reader :db_name

    class << self
      # Registry pattern using class variables to maintain singleton instances
      # per database. This ensures that lockfile operations for the same database
      # always work with the same instance, maintaining consistency.
      def for(db_name)
        @instances ||= {}
        @instances[db_name.to_sym] ||= new(db_name.to_sym)
      end

      def clear_instances!
        @instances = {}
      end

      private_class_method :new
    end

    def initialize(db_name = nil)
      @db_name = db_name || Nandi.config.default.name
    end

    def file_present?
      File.exist?(path)
    end

    def create!
      return if file_present?

      File.write(path, {}.to_yaml)
    end

    def add(file_name:, source_digest:, compiled_digest:)
      load!

      @lockfile[file_name] = {
        source_digest: source_digest,
        compiled_digest: compiled_digest,
      }
    end

    def get(file_name)
      load!

      {
        source_digest: @lockfile.dig(file_name, :source_digest),
        compiled_digest: @lockfile.dig(file_name, :compiled_digest),
      }
    end

    def load!
      return @lockfile if @lockfile

      create! unless file_present?

      @lockfile = YAML.safe_load_file(path).with_indifferent_access
    end

    def persist!
      load!
      # This is a somewhat ridiculous trick to avoid merge conflicts in git.
      #
      # Normally, new migrations are added to the bottom of the Nandi lockfile.
      # This is relatively unfriendly to git's merge algorithm, and means that
      # if someone merges a pull request with a completely unrelated migration,
      # you'll have to rebase to get yours merged as the last line of the file
      # will be seen as a conflict (both branches added content there).
      #
      # This is in contrast to something like Gemfile.lock, where changes tend
      # to be distributed throughout the file. The idea behind sorting by
      # SHA-256 hash is to distribute new Nandi lockfile entries evenly, but
      # also stably through the file. It needs to be stable or we'd have even
      # worse merge conflict problems (e.g. if we randomised the order on
      # writing the file, the whole thing would conflict pretty much every time
      # it was regenerated).
      content = @lockfile.to_h.deep_stringify_keys.sort_by do |k, _|
        Digest::SHA256.hexdigest(k)
      end.to_h.to_yaml

      File.write(path, content)
    end

    private

    def path
      Nandi.config.lockfile_path(@db_name)
    end
  end
end
