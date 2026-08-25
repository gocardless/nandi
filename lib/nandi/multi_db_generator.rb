# frozen_string_literal: true

module Nandi
  module MultiDbGenerator
    def self.included(base)
      base.class_option :database,
                        default: nil,
                        type: :string,
                        desc: "Database to migrate in multi-database mode. " \
                              "If not specified, uses specified default or primary database"
    end

    def superclass_name
      database_type = Nandi.config.database_type(db_name)
      database = Nandi::DATABASES.fetch(database_type) do
        raise "Unsupported database type #{database_type}"
      end
      database.superclass_name
    end

    private

    def db_name
      options["database"]&.to_sym
    end

    def base_path
      Nandi.config.migration_directory(db_name)
    end
  end
end
