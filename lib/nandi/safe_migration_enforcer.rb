# frozen_string_literal: true

require "digest"
require "rails"
require "rails/generators"

require "nandi/file_diff"
require "nandi/file_matcher"
require "nandi/lockfile"

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
      errors = collect_errors_from_databases

      if errors.any?
        raise MigrationLintingFailed, errors.join("\n\n")
      end

      true
    end

    private

    def collect_errors_from_databases
      errors = []

      Nandi.config.databases.each do |database|
        safe_migrations = matching_migrations(database.migration_directory)
        ar_migrations = matching_migrations(database.output_directory)

        next if safe_migrations.none? && ar_migrations.none?

        errors.concat(check_ungenerated_migrations(safe_migrations, ar_migrations))
        errors.concat(check_hand_written_migrations(safe_migrations, ar_migrations))
        errors.concat(check_out_of_date_migrations(safe_migrations, database))
        errors.concat(check_hand_edited_migrations(ar_migrations, database))
      end

      errors
    end

    def matching_migrations(dir)
      return [] unless Dir.exist?(dir)

      names = Dir.glob(File.join(dir, "*.rb")).map { |path| File.basename(path) }
      FileMatcher.call(files: names, spec: @files)
    end

    def check_ungenerated_migrations(safe_migrations, ar_migrations)
      ungenerated_migrations = safe_migrations - ar_migrations
      return [] if ungenerated_migrations.empty?

      [<<~ERROR.strip]
        The following migrations are pending generation:

          - #{ungenerated_migrations.sort.join("\n  - ")}

        Please run `rails generate nandi:compile` to generate your migrations.
      ERROR
    end

    def check_hand_written_migrations(safe_migrations, ar_migrations)
      handwritten_migrations = ar_migrations - safe_migrations
      return [] if handwritten_migrations.empty?

      [<<~ERROR.strip]
        The following migrations have been written by hand, not generated:

          - #{handwritten_migrations.sort.join("\n  - ")}

        Please use Nandi to generate your migrations. In exeptional cases, hand-written
        ActiveRecord migrations can be added to the .nandiignore file. Doing so will
        require additional review that will slow your PR down.
      ERROR
    end

    def check_out_of_date_migrations(safe_migrations, database_config)
      out_of_date_migrations = safe_migrations.
        map { |m| [m, Nandi::Lockfile.for(database_config.name).get(file_name: m)] }.
        select do |filename, digests|
          Nandi::FileDiff.new(
            file_path: File.join(database_config.migration_directory, filename),
            known_digest: digests[:source_digest],
          ).changed?
        end

      return [] if out_of_date_migrations.empty?

      [<<~ERROR.strip]
        The following migrations have changed but not been recompiled:

          - #{out_of_date_migrations.map(&:first).sort.join("\n  - ")}

        Please recompile your migrations to make sure that the changes you expect are
        applied.
      ERROR
    end

    def check_hand_edited_migrations(ar_migrations, database_config)
      hand_altered_migrations = ar_migrations.
        map { |m| [m, Nandi::Lockfile.for(database_config.name).get(file_name: m)] }.
        select do |filename, digests|
          Nandi::FileDiff.new(
            file_path: File.join(database_config.output_directory, filename),
            known_digest: digests[:compiled_digest],
          ).changed?
        end

      return [] if hand_altered_migrations.empty?

      [<<~ERROR.strip]
        The following migrations have had their generated content altered:

          - #{hand_altered_migrations.map(&:first).sort.join("\n  - ")}

        Please don't hand-edit generated migrations. If you want to write a regular
        ActiveRecord::Migration, please do so and add it to .nandiignore. Note that
        this will require additional review that will slow your PR down.
      ERROR
    end
  end
end
