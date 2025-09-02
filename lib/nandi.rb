# frozen_string_literal: true

require "nandi/config"
require "nandi/renderers"
require "nandi/compiled_migration"
require "active_support/core_ext/string/inflections"

module Nandi
  class Error < StandardError; end

  class << self
    def compile(files:, db_name: nil)
      compiled = files.
        map { |f| CompiledMigration.build(file_name: f, db_name: db_name) }

      yield compiled
    end

    def configure
      yield config
      config.validate!
    end

    def validator
      Nandi::Validator
    end

    def config
      @config ||= Config.new
    end
  end
end
