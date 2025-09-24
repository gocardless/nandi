# frozen_string_literal: true

module Nandi
  class MultiDatabase
    class Database
      # Most DDL changes take a very strict lock, but execute very quickly. For these
      # the statement timeout should be very tight, so that if there's an unexpected
      # delay the query queue does not back up.
      DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT = 1_500
      DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT = 5_000

      DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT =
        DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
      DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT =
        DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT
      DEFAULT_CONCURRENT_TIMEOUT_LIMIT = 3_600_000

      DEFAULT_MIGRATION_DIRECTORY = "db/safe_migrations"
      DEFAULT_OUTPUT_DIRECTORY = "db/migrate"

      # The default lock timeout for migrations that take ACCESS EXCLUSIVE
      # locks. Can be overridden by way of the `set_lock_timeout` class
      # method in a given migration. Default: 1500ms.
      # @return [Integer]
      attr_accessor :access_exclusive_lock_timeout

      # The default statement timeout for migrations that take ACCESS EXCLUSIVE
      # locks. Can be overridden by way of the `set_statement_timeout` class
      # method in a given migration. Default: 1500ms.
      # @return [Integer]
      attr_accessor :access_exclusive_statement_timeout

      # The maximum lock timeout for migrations that take an ACCESS EXCLUSIVE
      # lock and therefore block all reads and writes. Default: 5,000ms.
      # @return [Integer]
      attr_accessor :access_exclusive_statement_timeout_limit

      # The maximum statement timeout for migrations that take an ACCESS
      # EXCLUSIVE lock and therefore block all reads and writes. Default: 1500ms.
      # @return [Integer]
      attr_accessor :access_exclusive_lock_timeout_limit

      # The minimum statement timeout for migrations that take place concurrently.
      # Default: 3,600,000ms (ie, 3 hours).
      # @return [Integer]
      attr_accessor :concurrent_statement_timeout_limit

      # The minimum lock timeout for migrations that take place concurrently.
      # Default: 3,600,000ms (ie, 3 hours).
      # @return [Integer]
      attr_accessor :concurrent_lock_timeout_limit

      # The directory for output files. Default: `db/migrate`
      # @return [String]
      attr_accessor :output_directory

      attr_reader :name, :default

      attr_accessor :migration_directory,
                    :lockfile_path

      def initialize(name:, config:)
        @name = name
        @default = @name == :primary || config[:default] == true

        # Paths and files - all follow the same pattern
        @migration_directory = config[:migration_directory] || "db/#{path_prefix(name, default)}safe_migrations"
        @output_directory = config[:output_directory] || "db/#{path_prefix(name, default)}migrate"
        @lockfile_path = config[:lockfile_path] || "db/.#{path_prefix(name, default)}nandilock.yml"

        timeout_limits(config)
      end

      private

      def timeout_limits(config)
        @access_exclusive_lock_timeout =
          config[:access_exclusive_lock_timeout] || DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT
        @access_exclusive_statement_timeout =
          config[:access_exclusive_statement_timeout] || DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
        @access_exclusive_lock_timeout_limit =
          config[:access_exclusive_lock_timeout_limit] || DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT
        @access_exclusive_statement_timeout_limit =
          config[:access_exclusive_statement_timeout_limit] || DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT
        @concurrent_lock_timeout_limit =
          config[:concurrent_lock_timeout_limit] || DEFAULT_CONCURRENT_TIMEOUT_LIMIT
        @concurrent_statement_timeout_limit =
          config[:concurrent_statement_timeout_limit] || DEFAULT_CONCURRENT_TIMEOUT_LIMIT
      end

      def path_prefix(name, default)
        default ? "" : "#{name}_"
      end
    end

    def initialize
      @databases = {}
    end

    def config(name = nil)
      # If name isnt specified, return config for the default database. This mimics behavior
      # of the rails migration commands.
      return default if name.nil?

      name = name.to_sym
      db_config = @databases[name]
      raise ArgumentError, "Missing database configuration for #{name}" if db_config.nil?

      db_config
    end

    def default
      @databases.values.find(&:default)
    end

    def register(name, config)
      name = name.to_sym
      raise ArgumentError, "Database #{name} already registered" if @databases.key?(name)

      @databases[name] = Database.new(name: name, config: config)
    end

    def names
      @databases.keys
    end

    def validate!
      enforce_default_db_for_multi_database!
      enforce_names_for_multi_database!
      validate_unique_migration_directories!
      validate_unique_output_directories!
    end

    delegate :each, :map, to: :@databases

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

    def enforce_names_for_multi_database!
      # If we're in multi-db mode, enforce that all databases have a name
      return if @databases.count <= 1

      unknown_names = @databases.keys.select(&:nil?)
      if unknown_names.any?
        raise ArgumentError, "Databases must have a name in multi-db mode"
      end
    end
  end
end
