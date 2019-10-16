# frozen_string_literal: true

require "rails/generators"

module Nandi
  class MigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    def create_migration_file
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      template(
        "migration.rb",
        "#{base_path}/#{timestamp}_#{snakecase(file_name)}.rb",
      )
    end

    private

    def base_path
      Nandi.config.migration_directory || "db/safe_migrations"
    end

    def snakecase(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr("-", "_").
        gsub(/\s/, "_").
        gsub(/__+/, "_").
        downcase
    end
  end
end
