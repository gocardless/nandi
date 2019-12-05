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
                 default: "git-diff",
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

    def safe_migrations_glob
      if Nandi.config.migration_directory.nil?
        Rails.root.join("db", "safe_migrations", "*.rb").to_s
      else
        File.expand_path("*.rb", Nandi.config.migration_directory)
      end
    end

    def output_path
      Nandi.config.output_directory || "db/migrate"
    end

    def files
      FileMatcher.call(files: Dir.glob(safe_migrations_glob), spec: options["files"])
    end
  end
end
