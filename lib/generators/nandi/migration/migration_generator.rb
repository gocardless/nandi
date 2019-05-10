# frozen_string_literal: true

require "rails/generators"

module Nandi
  class MigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    def create_migration_file
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      template(
        "migration.rb",
        "db/safe_migrations/#{timestamp}_#{file_name.snakecase}.rb",
      )
    end
  end
end
