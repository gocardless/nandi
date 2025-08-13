# frozen_string_literal: true

module Nandi
  class MultiDatabase
    class Database
      attr_reader :name, :default, :migration_directory, :output_directory, :lockfile_name

      def initialize(name:, config:)
        @name = name
        @config = config
        @migration_directory = config[:migration_directory] || "db/#{name}_safe_migrations"
        @output_directory = config[:output_directory] || "db/#{name}_migrate"
        @lockfile_name = config[:lockfile_name] || ".#{name}_nandilock.yml"
        @default = (true if @name == :primary) || config[:default]

        raise ArgumentError, "Missing database name" if @name.nil?
      end
    end

    def initialize
      @databases = {}
    end

    def config(name)
      # If name isnt specified, return config for the default database. This mimics behavior
      # of the rails migration commands.
      return default_database if name.nil?

      name = name.to_sym
      db_config = @databases[name]
      raise ArgumentError, "Missing database configuration for #{name}" if db_config.nil?

      db_config
    end

    def default_database
      @databases.values.find(&:default)
    end

    def register(name, config)
      name = name.to_sym
      raise ArgumentError, "Database #{name} already registered" if @databases.key?(name)

      @databases[name] = Database.new(name: name, config: config)
    end

    def enabled?
      @databases.present?
    end

    def names
      @databases.keys
    end

    def validate!
      return if !enabled?

      enforce_default_db_for_multi_database!
      validate_unique_migration_directories!
      validate_unique_output_directories!
    end

    private

    def enforce_default_db_for_multi_database!
      # If there is a `primary` database, we take that as the default database
      # following rails behavior. If not, we will validate that there is one specified
      # default database using the `default: true` option.
      if @databases.values.none?(&:default)
        raise ArgumentError, "Missing default database. Specify a default database using the `default: true` option " \
                             "or by registering `primary` as a database name."
      end
      if @databases.values.count(&:default) > 1
        raise ArgumentError, "Multiple default databases specified: " \
                             "#{@databases.values.select(&:default).map(&:name).join(', ')}"
      end
    end

    def validate_unique_migration_directories!
      paths = @databases.values.map(&:migration_directory).uniq.filter(&:present?)
      if paths.length != @databases.values.length
        raise ArgumentError,
              "Unique migration directories must be specified for each database"
      end
    end

    def validate_unique_output_directories!
      paths = @databases.values.map(&:output_directory).uniq.filter(&:present?)
      if paths.length != @databases.values.length
        raise ArgumentError,
              "Unique output directories must be specified for each database"
      end
    end
  end
end
