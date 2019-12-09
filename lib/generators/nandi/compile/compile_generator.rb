# frozen_string_literal: true

require "rails/generators"
require "nandi"
require "nandi/migration"
require "nandi/file_matcher"

module Nandi
  class CompileGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

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
      Nandi.compile(files: files) do |results|
        results.each do |result|
          create_file "#{output_path}/#{result.file_name}", result.body, force: true
        end
      end
    end

    private

    def safe_migrations_dir
      if Nandi.config.migration_directory.nil?
        Rails.root.join("db", "safe_migrations").to_s
      else
        File.expand_path(Nandi.config.migration_directory)
      end
    end

    def output_path
      Nandi.config.output_directory || "db/migrate"
    end

    def files
      safe_migration_files = Dir.chdir(safe_migrations_dir) { Dir["*.rb"] }
      FileMatcher.call(files: safe_migration_files, spec: options["files"]).
        map { |file| File.join(safe_migrations_dir, file) }
    end
  end
end
