# frozen_string_literal: true

require "rails/generators"

module Nandi
  class MigrationGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    class_option :database,
                 type: :string,
                 desc: "Database to create migration for (multi-database support)"

    def create_migration_file
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      template(
        "migration.rb",
        "#{base_path}/#{timestamp}_#{file_name.underscore}.rb",
      )
    end

    private

    def base_path
      if options[:database]
        database_sym = options[:database].to_sym
        Nandi.config.migration_directory_for(database_sym)
      else
        Nandi.config.migration_directory || "db/safe_migrations"
      end
    end

    def target_database
      options[:database]&.to_sym
    end
  end
end
