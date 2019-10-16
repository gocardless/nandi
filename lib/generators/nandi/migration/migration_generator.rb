# frozen_string_literal: true

require "rails/generators"

module Nandi
  class MigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    def create_migration_file
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      template(
        "migration.rb",
        "#{base_path}/#{timestamp}_#{file_name.underscore}.rb",
      )
    end

    private

    def base_path
      Nandi.config.migration_directory || "db/safe_migrations"
    end
  end
end
