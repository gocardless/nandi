# frozen_string_literal: true

require "rails/generators"
require "nandi"
require "nandi/migration"

module Nandi
  class CompileGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :files,
                 type: :string,
                 default: "git-diff",
                 desc: <<-DESC
                 Files to compile. May be a glob pattern or one of the following:
                 -- 'all' compiles all files
                 -- 'git-diff' only changed.
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

    def compiled_migrations_glob
      File.expand_path("*.rb", output_path)
    end

    def output_path
      Nandi.config.output_directory || "db/migrate"
    end

    def files
      safe_migrations = Dir.glob(safe_migrations_glob)
      case options["files"]
      when "all"
        safe_migrations
      when "git-diff"
        changed_files & safe_migrations
      else
        Dir.glob(options["files"])
      end
    end

    def changed_files
      `git status -s`.lines.map do |line|
        Rails.root.join(line.chomp.strip.split[1]).to_s
      end
    end
  end
end
