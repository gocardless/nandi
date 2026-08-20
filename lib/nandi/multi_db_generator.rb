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
      case database_type
      when :postgres
        postgres_classname
      when :yugabyte
        "Nandi::Migration::Yugabyte"
      else
        raise "Unsupported database type #{database_type}"
      end
    end

    private

    def db_name
      options["database"]&.to_sym
    end

    def base_path
      Nandi.config.migration_directory(db_name)
    end

    def postgres_classname
      if Nandi.config.suppress_postgres_classname
        "Nandi::Migration"
      else
        "Nandi::Migration::Postgres"
      end
    end
  end
end
