# frozen_string_literal: true

require "digest"
require "rails"
require "rails/generators"

require "nandi/file_diff"
require "nandi/file_matcher"
require "nandi/lockfile"
require "nandi/migration_violations"

module Nandi
  class SafeMigrationEnforcer
    class MigrationLintingFailed < StandardError; end

    DEFAULT_SAFE_MIGRATION_DIR = "db/safe_migrations"
    DEFAULT_AR_MIGRATION_DIR = "db/migrate"
    DEFAULT_FILE_SPEC = "all"

    attr_reader :violations

    def initialize(require_path: nil,
                   safe_migration_dir: DEFAULT_SAFE_MIGRATION_DIR,
                   ar_migration_dir: DEFAULT_AR_MIGRATION_DIR,
                   files: DEFAULT_FILE_SPEC)
      @files = files

      require require_path unless require_path.nil?

      configure_legacy_mode_if_needed(safe_migration_dir, ar_migration_dir)
      @violations = MigrationViolations.new
    end

    def run
      collect_violations

      if violations.any?
        raise MigrationLintingFailed, violations.to_error_message
      end

      true
    end

    private

    def configure_legacy_mode_if_needed(safe_dir, ar_dir)
      legacy_mode = safe_dir != DEFAULT_SAFE_MIGRATION_DIR ||
        ar_dir != DEFAULT_AR_MIGRATION_DIR

      return unless legacy_mode

      Nandi.configure do |c|
        c.migration_directory = safe_dir
        c.output_directory = ar_dir
      end
    end

    def collect_violations
      Nandi.config.databases.each do |_, database|
        check_database_violations(database)
      end
    end

    def check_database_violations(database)
      safe_migrations = matching_migrations(database.migration_directory)
      ar_migrations = matching_migrations(database.output_directory)

      check_ungenerated_migrations(safe_migrations, ar_migrations, database)
      check_handwritten_migrations(safe_migrations, ar_migrations, database)
      check_out_of_date_migrations(safe_migrations, database)
      check_hand_edited_migrations(ar_migrations, database)
    end

    def check_ungenerated_migrations(safe_migrations, ar_migrations, database)
      missing_files = (safe_migrations - ar_migrations)
      violations.add_ungenerated(missing_files, database.migration_directory)
    end

    def check_handwritten_migrations(safe_migrations, ar_migrations, database)
      handwritten_files = (ar_migrations - safe_migrations)
      violations.add_handwritten(handwritten_files, database.output_directory)
    end

    def check_out_of_date_migrations(safe_migrations, database)
      out_of_date_files = find_changed_files(
        safe_migrations,
        database,
        :source_digest,
        database.migration_directory,
      )
      violations.add_out_of_date(out_of_date_files, database.migration_directory)
    end

    def check_hand_edited_migrations(ar_migrations, database)
      hand_edited_files = find_changed_files(
        ar_migrations,
        database,
        :compiled_digest,
        database.output_directory,
      )
      violations.add_hand_edited(hand_edited_files, database.output_directory)
    end

    def find_changed_files(filenames, database, digest_key, directory)
      filenames.filter_map do |filename|
        digests = Nandi::Lockfile.for(database.name).get(filename)
        file_diff = Nandi::FileDiff.new(
          file_path: File.join(directory, filename),
          known_digest: digests[digest_key],
        )
        filename if file_diff.changed?
      end
    end

    def matching_migrations(directory)
      return [] unless Dir.exist?(directory)

      filenames = Dir.glob(File.join(directory, "*.rb")).map { |path| File.basename(path) }
      FileMatcher.call(files: filenames, spec: @files)
    end
  end
end
