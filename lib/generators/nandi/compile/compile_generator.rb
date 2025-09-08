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
                 type: :string,
                 desc: "Database to compile. " \
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
      databases.each do |db_name|
        Nandi.compile(files: files(db_name), db_name: db_name) do |results|
          results.each do |result|
            Nandi::Lockfile.for(db_name).add(
              file_name: result.file_name,
              source_digest: result.source_digest,
              compiled_digest: result.compiled_digest,
            )
            unless result.migration_unchanged?
              create_file result.output_path, result.body, force: true
            end
          end
        end
        Nandi::Lockfile.for(db_name).persist!
      end
    end

    private

    def databases
      return [options[:database].to_sym] if options[:database]

      Nandi.config.databases.names
    end

    def safe_migrations_dir(db_name)
      File.expand_path(Nandi.config.migration_directory(db_name))
    end

    def files(db_name)
      safe_migration_files = Dir.chdir(safe_migrations_dir(db_name)) { Dir["*.rb"] }
      FileMatcher.call(files: safe_migration_files, spec: options["files"])
    end
  end
end
