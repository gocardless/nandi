# frozen_string_literal: true

require "nandi/config"
require "nandi/migration"
require "nandi/renderers"
require "active_support/core_ext/string/inflections"

module Nandi
  class InvalidMigrationError < StandardError; end
  class Error < StandardError; end

  CompiledMigration = Struct.new(:file_name, :body)

  class << self
    def compile(files:)
      yield files.map(&method(:compiled_migration))
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

    private

    def compiled_migration(file_path)
      require file_path

      file_name, class_name = /\d+_([a-z_]+)\.rb\z/.match(file_path)[0..1]

      migration = class_name.camelize.constantize.new(validator)

      raise InvalidMigrationError, "Migration not valid" unless migration.valid?

      CompiledMigration.new(
        file_name,
        body(migration),
      )
    end

    def body(migration)
      compiled_body = config.renderer.generate(migration)

      if Nandi.config.post_processor
        Nandi.config.post_processor.call(compiled_body)
      else
        compiled_body
      end
    end
  end
end
