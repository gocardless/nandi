# frozen_string_literal: true

require "nandi/file_diff"
require "nandi/lockfile"

module Nandi
  module Violations
    class BaseViolations
      attr_reader :files

      def initialize
        @files = []
      end

      def any?
        files.any?
      end

      def to_s
        return "" unless any?

        generate_message
      end

      def add_violations(**kwargs)
        violations = check_files(**kwargs)
        @files.concat(violations)
      end

      private

      def check_files(**kwargs)
        raise NotImplementedError, "Subclasses must implement #check_files"
      end

      def generate_message
        raise NotImplementedError, "Subclasses must implement #generate_message"
      end
    end

    class UngeneratedMigrationViolations < BaseViolations
      private

      def check_files(safe_migrations:, ar_migrations:, **_kwargs)
        safe_migrations - ar_migrations
      end

      def generate_message
        <<~ERROR.strip
          The following migrations are pending generation:

            - #{files.sort.join("\n  - ")}

          Please run `rails generate nandi:compile` to generate your migrations.
        ERROR
      end
    end

    class HandWrittenMigrationViolations < BaseViolations
      private

      def check_files(ar_migrations:, safe_migrations:)
        ar_migrations - safe_migrations
      end

      def generate_message
        <<~ERROR.strip
          The following migrations have been written by hand, not generated:

            - #{files.sort.join("\n  - ")}

          Please use Nandi to generate your migrations. In exeptional cases, hand-written
          ActiveRecord migrations can be added to the .nandiignore file. Doing so will
          require additional review that will slow your PR down.
        ERROR
      end
    end

    class OutOfDateMigrationViolations < BaseViolations
      private

      def check_files(database_config:, safe_migrations:, **_kwargs)
        out_of_date_migrations = safe_migrations.
          map { |m| [m, Nandi::Lockfile.for(database_config.name).get(file_name: m)] }.
          select do |filename, digests|
            Nandi::FileDiff.new(
              file_path: File.join(database_config.migration_directory, filename),
              known_digest: digests[:source_digest],
            ).changed?
          end

        out_of_date_migrations.map(&:first)
      end

      def generate_message
        <<~ERROR.strip
          The following migrations have changed but not been recompiled:

            - #{files.sort.join("\n  - ")}

          Please recompile your migrations to make sure that the changes you expect are
          applied.
        ERROR
      end
    end

    class HandEditedMigrationViolations < BaseViolations
      private

      def check_files(database_config:, ar_migrations:, **_kwargs)
        hand_altered_migrations = ar_migrations.
          map { |m| [m, Nandi::Lockfile.for(database_config.name).get(file_name: m)] }.
          select do |filename, digests|
            Nandi::FileDiff.new(
              file_path: File.join(database_config.output_directory, filename),
              known_digest: digests[:compiled_digest],
            ).changed?
          end

        hand_altered_migrations.map(&:first)
      end

      def generate_message
        <<~ERROR.strip
          The following migrations have had their generated content altered:

            - #{files.sort.join("\n  - ")}

          Please don't hand-edit generated migrations. If you want to write a regular
          ActiveRecord::Migration, please do so and add it to .nandiignore. Note that
          this will require additional review that will slow your PR down.
        ERROR
      end
    end
  end
end
