# frozen_string_literal: true

require "rails/generators"
require "nandi"
require "nandi/migration"

module Nandi
  class CompileGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    def compile_migration_files
      Nandi.compile(files: Dir.glob(safe_migrations_glob)) do |results|
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
  end
end
