# frozen_string_literal: true

require "digest"
require "rails"
require "rails/generators"

require "nandi/file_matcher"

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
      @safe_migration_dir = safe_migration_dir
      @ar_migration_dir = ar_migration_dir
      @files = files

      require require_path unless require_path.nil?

      Nandi.configure do |c|
        c.migration_directory = @safe_migration_dir
        c.output_directory = @ar_migration_dir
      end
    end

    def run
      safe_migrations = matching_migrations(@safe_migration_dir)
      ar_migrations = matching_migrations(@ar_migration_dir)

      return true if safe_migrations.none? && ar_migrations.none?

      exceptions = Nandi.ignored_files

      enforce_no_ungenerated_migrations!(safe_migrations, ar_migrations)
      enforce_no_hand_written_migrations!(safe_migrations, ar_migrations, exceptions)
      enforce_no_hand_edited_migrations!(ar_migrations)

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

    def enforce_no_hand_written_migrations!(safe_migrations, ar_migrations, exceptions)
      handwritten_migrations = ar_migrations - safe_migrations
      handwritten_migration_paths = names_to_paths(handwritten_migrations)

      disallowed_handwritten_migrations = handwritten_migration_paths - exceptions

      if disallowed_handwritten_migrations.any?
        error = <<~ERROR
          The following migrations have been written by hand, not generated:

            - #{disallowed_handwritten_migrations.sort.join("\n  - ")}

          Please use Nandi to generate your migrations. In exeptional cases, hand-written
          ActiveRecord migrations can be added to the .nandiignore file. Doing so will
          require additional review that will slow your PR down.
        ERROR

        raise MigrationLintingFailed, error
      end
    end

    def enforce_no_hand_edited_migrations!(ar_migrations)
      ar_migration_paths = names_to_paths(ar_migrations)

      initial_migration_digests = {}
      ar_migration_paths.each do |migration|
        content = File.read(migration)
        digest = Digest::SHA256.hexdigest(content)
        initial_migration_digests[migration] = digest
      end

      Rails::Generators.invoke("nandi:compile", ["--files", @files])

      migration_digests_after_compile = {}
      ar_migration_paths.each do |migration|
        content = File.read(migration)
        digest = Digest::SHA256.hexdigest(content)
        migration_digests_after_compile[migration] = digest
      end

      hand_altered_migrations = []
      initial_migration_digests.each do |migration, digest|
        if digest != migration_digests_after_compile[migration]
          hand_altered_migrations << migration
        end
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

    def names_to_paths(names)
      names.map { |name| File.join(@ar_migration_dir, name) }
    end
  end
end
