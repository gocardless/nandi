# frozen_string_literal: true

require "rails/generators"
require "nandi"
require "nandi/migration"
require "nandi/file_matcher"
require "nandi/lockfile"

module Nandi
  class CompileGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :database,
                 type: string,
                 desc: "Database to compile in multi-database mode. " \
                       "If not specified, compiles for all databases"

    class_option :files,
                 type: :string,
                 default: Nandi.config.compile_files,
                 desc: <<-DESC
                 Files to compile. May be one of the following:
                 -- 'all' compiles all files
                 -- 'git-diff' only changed
                 -- a full or partial version timestamp, eg '20190101010101', '20190101'
                 -- a timestamp range , eg '>=20190101010101'
                 DESC

    def compile_migration_files
      databases.each do |database|
        Nandi.compile(database: database, files: files(database)) do |results|
          results.each do |result|
            Nandi::Lockfile.add(
              file_name: result.file_name,
              source_digest: result.source_digest,
              compiled_digest: result.compiled_digest,
            )

            unless result.migration_unchanged?
              create_file result.output_path, result.body, force: true
            end
          end
        end

        Nandi::Lockfile.persist!
      end
    end

    private

    def files(db_name)
      safe_migrations_dir = Nandi.config.migration_directory(db_name)
      safe_migration_files = Dir.chdir(safe_migrations_dir) { Dir["*.rb"] }
      FileMatcher.call(files: safe_migration_files, spec: options["files"]).
        map { |file| File.join(safe_migrations_dir, file) }
    end

    def databases
      return [options["database"]] if options["database"]

      Nandi.config.database_names
    end
  end
end
