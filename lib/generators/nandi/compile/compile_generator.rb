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
          create_file "db/migrate/#{result.file_name}", result.body, force: true
        end
      end
    end

    private

    def safe_migrations_glob
      Rails.root.join("db", "safe_migrations", "*.rb").to_s
    end
  end
end
