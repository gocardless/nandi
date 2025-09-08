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

      legacy_mode = safe_migration_dir != DEFAULT_SAFE_MIGRATION_DIR ||
        ar_migration_dir != DEFAULT_AR_MIGRATION_DIR

      # Configure for backward compatibility in legacy mode
      if legacy_mode
        Nandi.configure do |c|
          c.migration_directory = safe_migration_dir
          c.output_directory = ar_migration_dir
        end
      end
    end

    def run
      Nandi.config.databases.map do |db_name, _|
        enforce_for_database!(db_name)
      end.all?
    end

    def enforce_for_database!(db_name)
      safe_migrations = matching_migrations(Nandi.config.config(db_name).migration_directory)
      ar_migrations = matching_migrations(Nandi.config.config(db_name).output_directory)

      return true if safe_migrations.none? && ar_migrations.none?

      enforce_no_ungenerated_migrations!(safe_migrations, ar_migrations)
      enforce_no_hand_written_migrations!(safe_migrations, ar_migrations)
      enforce_no_hand_edited_migrations!(ar_migrations, db_name)
      enforce_no_out_of_date_migrations!(safe_migrations, db_name)

      true
    end

    private

    def matching_migrations(dir)
      names = Dir.glob(File.join(dir, "*.rb")).map { |path| File.basename(path) }
      FileMatcher.call(files: names, spec: @files)
    end

    def enforce_no_ungenerated_migrations!(safe_migrations, ar_migrations)
      ungenerated_migrations = safe_migrations - ar_migrations
      if ungenerated_migrations.any?
        error = <<~ERROR
          The following migrations are pending generation:

            - #{ungenerated_migrations.sort.join("\n  - ")}

          Please run `rails generate nandi:compile` to generate your migrations.
        ERROR

        raise MigrationLintingFailed, error
      end
    end

    def enforce_no_hand_written_migrations!(safe_migrations, ar_migrations)
      handwritten_migrations = ar_migrations - safe_migrations

      if handwritten_migrations.any?
        error = <<~ERROR
          The following migrations have been written by hand, not generated:

            - #{handwritten_migrations.sort.join("\n  - ")}

          Please use Nandi to generate your migrations. In exeptional cases, hand-written
          ActiveRecord migrations can be added to the .nandiignore file. Doing so will
          require additional review that will slow your PR down.
        ERROR

        raise MigrationLintingFailed, error
      end
    end

    def enforce_no_out_of_date_migrations!(safe_migrations, db_name)
      out_of_date_migrations = safe_migrations.
        map { |m| [m, Nandi::Lockfile.for(db_name).get(m)] }.
        select do |filename, digests|
          Nandi::FileDiff.new(
            file_path: File.join(Nandi.config.config(db_name).migration_directory, filename),
            known_digest: digests[:source_digest],
          ).changed?
        end

      if out_of_date_migrations.any?
        error = <<~ERROR
          The following migrations have changed but not been recompiled:

            - #{out_of_date_migrations.sort.join("\n  - ")}

          Please recompile your migrations to make sure that the changes you expect are
          applied.
        ERROR

        raise MigrationLintingFailed, error
      end
    end

    def enforce_no_hand_edited_migrations!(ar_migrations, db_name)
      hand_altered_migrations = ar_migrations.
        map { |m| [m, Nandi::Lockfile.for(db_name).get(m)] }.
        select do |filename, digests|
          Nandi::FileDiff.new(
            file_path: File.join(Nandi.config.config(db_name).output_directory, filename),
            known_digest: digests[:compiled_digest],
          ).changed?
        end

      if hand_altered_migrations.any?
        error = <<~ERROR
          The following migrations have had their generated content altered:

            - #{hand_altered_migrations.sort.join("\n  - ")}

          Please don't hand-edit generated migrations. If you want to write a regular
          ActiveRecord::Migration, please do so and add it to .nandiignore. Note that
          this will require additional review that will slow your PR down.
        ERROR

        raise MigrationLintingFailed, error
      end
    end
  end
end
