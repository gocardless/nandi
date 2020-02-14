# frozen_string_literal: true

require "nandi/config"
require "nandi/renderers"
require "nandi/compiled_migration"
require "active_support/core_ext/string/inflections"

module Nandi
  class Error < StandardError; end

  class << self
    def compile(files:)
      compiled = files.
        map { |f| CompiledMigration.build(f) }

      yield compiled
    end

    def configure
      yield config
    end

    def validator
      Nandi::Validator
    end

    def config
      @config ||= Config.new
    end

    def compiled_output_directory
      Nandi.config.output_directory || "db/migrate"
    end
  end
end
