# frozen_string_literal: true

require "rails/generators"
require "nandi/multi_db_generator"

module Nandi
  class MigrationGenerator < Rails::Generators::NamedBase
    include Nandi::MultiDbGenerator

    source_root File.expand_path("templates", __dir__)

    def create_migration_file
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      template(
        "migration.rb",
        "#{base_path}/#{timestamp}_#{file_name.underscore}.rb",
      )
    end
  end
end
