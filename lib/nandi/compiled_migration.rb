# frozen_string_literal: true

require "nandi/file_diff"

module Nandi
  class CompiledMigration
    class InvalidMigrationError < StandardError; end

    attr_reader :file_name, :source_file_path, :class_name

    def self.build(source_file_path)
      new(source_file_path)
    end

    def initialize(source_file_path)
      @source_file_path = source_file_path
      require source_file_path

      @file_name, @class_name = /\d+_([a-z0-9_]+)\.rb\z/.match(source_file_path)[0..1]
    end

    def body
      @body ||= if migration_unchanged?
                  File.read(output_path)
                else
                  migration = class_name.camelize.constantize.new(Nandi.validator)

                  validation = migration.validate
                  unless validation.valid?
                    raise InvalidMigrationError, "Migration #{source_file_path} " \
                      "is not valid:\n#{validation.error_list}"
                  end

                  compiled_body(migration)
                end
    end

    def output_path
      "#{Nandi.compiled_output_directory}/#{file_name}"
    end

    def compiled_digest
      Digest::SHA256.hexdigest(body)
    end

    def source_digest
      Digest::SHA256.hexdigest(File.read(source_file_path))
    end

    private

    def migration_unchanged?
      return unless File.exist?(output_path)

      source_migration_diff = Nandi::FileDiff.new(
        file_path: source_file_path,
        known_digest: Nandi::Lockfile.get(file_name).fetch(:source_digest),
      )

      compiled_migration_diff = Nandi::FileDiff.new(
        file_path: output_path,
        known_digest: Nandi::Lockfile.get(file_name).fetch(:compiled_digest),
      )

      source_migration_diff.unchanged? && compiled_migration_diff.unchanged?
    end

    def compiled_body(migration)
      compiled_body = Nandi.config.renderer.generate(migration)

      if Nandi.config.post_processor
        Nandi.config.post_processor.call(compiled_body)
      else
        compiled_body
      end
    end
  end
end
