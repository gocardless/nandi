# frozen_string_literal: true

require "digest"
require "rails"
require "rails/generators"

require "nandi/file_diff"
require "nandi/file_matcher"
require "nandi/lockfile"
require "nandi/violations"

module Nandi
  class SafeMigrationEnforcer
    class MigrationLintingFailed < StandardError; end

    DEFAULT_SAFE_MIGRATION_DIR = "db/safe_migrations"
    DEFAULT_AR_MIGRATION_DIR = "db/migrate"
    DEFAULT_FILE_SPEC = "all"

    def initialize(require_path: nil,
                   safe_migration_dir: DEFAULT_SAFE_MIGRATION_DIR,
                   ar_migration_dir: DEFAULT_AR_MIGRATION_DIR,
                   files: DEFAULT_FILE_SPEC)
      @files = files

      @ungenerated_violations = Violations::UngeneratedMigrationViolations.new
      @hand_written_violations = Violations::HandWrittenMigrationViolations.new
      @out_of_date_violations = Violations::OutOfDateMigrationViolations.new
      @hand_edited_violations = Violations::HandEditedMigrationViolations.new

      require require_path unless require_path.nil?

      # Flag to indicate if we're using legacy constructor with custom directories
      legacy_mode = safe_migration_dir != DEFAULT_SAFE_MIGRATION_DIR ||
        ar_migration_dir != DEFAULT_AR_MIGRATION_DIR

      # Configure for backward compatibility in legacy mode
      # (when using default directories, we rely on the default :primary database config)
      if legacy_mode
        Nandi.configure do |c|
          c.migration_directory = safe_migration_dir
          c.output_directory = ar_migration_dir
        end
      end
    end

    def run
      Nandi.config.databases.each do |database|
        check_database_migrations(database)
      end

      all_violations = [
        @ungenerated_violations,
        @hand_written_violations,
        @out_of_date_violations,
        @hand_edited_violations
      ].select(&:any?)

      if all_violations.any?
        raise MigrationLintingFailed, all_violations.map(&:to_s).join("\n\n")
      end

      true
    end

    private

    def check_database_migrations(database_config)
      safe_migrations = matching_migrations(database_config.migration_directory)
      ar_migrations = matching_migrations(database_config.output_directory)

      return if safe_migrations.none? && ar_migrations.none?

      @ungenerated_violations.add_violations(safe_migrations:, ar_migrations:, database_config:)
      @hand_written_violations.add_violations(safe_migrations:, ar_migrations:, database_config:)
      @hand_edited_violations.add_violations(ar_migrations:, database_config:)
      @out_of_date_violations.add_violations(safe_migrations:, database_config:)
    end

    def matching_migrations(dir)
      return [] unless Dir.exist?(dir)

      names = Dir.glob(File.join(dir, "*.rb")).map { |path| File.basename(path) }
      FileMatcher.call(files: names, spec: @files)
    end
  end
end
