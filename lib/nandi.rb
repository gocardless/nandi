# frozen_string_literal: true

require "nandi/config"
require "nandi/renderers"
require "active_support/core_ext/string/inflections"

module Nandi
  class InvalidMigrationError < StandardError; end
  class Error < StandardError; end

  CompiledMigration = Struct.new(:file_name, :body)

  class << self
    def ignored_files
      @ignored_files ||= if File.exist?(".nandiignore")
                           File.read(".nandiignore").lines.map(&:strip)
                         else
                           []
                         end
    end

    def ignored_filenames
      ignored_files.map(&File.method(:basename))
    end

    def compile(files:)
      compiled = files.reject { |f| ignored_filenames.include?(File.basename(f)) }.
        map(&method(:compiled_migration))

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

    private

    def compiled_migration(file_path)
      require file_path

      file_name, class_name = /\d+_([a-z_]+)\.rb\z/.match(file_path)[0..1]

      migration = class_name.camelize.constantize.new(validator)

      validation = migration.validate
      unless validation.valid?
        raise InvalidMigrationError, "Migration #{file_path} is not valid:\n" \
          "#{validation.error_list}"
      end

      CompiledMigration.new(file_name, body(migration))
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
