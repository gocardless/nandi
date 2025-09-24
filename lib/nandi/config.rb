# frozen_string_literal: true

require "nandi/renderers"
require "nandi/lockfile"
require "nandi/multi_database"

module Nandi
  class Config
    DEFAULT_COMPILE_FILES = "all"

    # The rendering backend used to produce output. The only supported option
    # at current is Nandi::Renderers::ActiveRecord, which produces ActiveRecord
    # migrations.
    # @return [Class]
    attr_accessor :renderer

    # The files to compile when the compile generator is run. Default: `all`
    # May be one of the following:
    # - 'all' compiles all files
    # - 'git-diff' only files changed since last commit
    # - a full or partial version timestamp, eg '20190101010101', '20190101'
    # - a timestamp range , eg '>=20190101010101'
    # @return [String]
    attr_accessor :compile_files


    # @api private
    attr_reader :post_processor, :custom_methods

    def initialize(renderer: Renderers::ActiveRecord)
      @renderer = renderer
      @custom_methods = {}
      @compile_files = DEFAULT_COMPILE_FILES
    end

    # Register a block to be called on output, for example a code formatter. Whatever is
    # returned will be written to the output file.
    # @yieldparam migration [string] The text of a compiled migration.
    def post_process(&block)
      @post_processor = block
    end

    # Register a custom DDL method.
    # @param name [Symbol] The name of the method to create. This will be monkey-patched
    #   into Nandi::Migration.
    # @param klass [Class] The class to initialise with the arguments to the
    #   method. It should define a `template` instance method which will return a
    #   subclass of Cell::ViewModel from the Cells templating library and a
    #   `procedure` method that returns the name of the method. It may optionally
    #   define a `mixins` method, which will return an array of `Module`s to be
    #   mixed into any migration that uses this method.
    def register_method(name, klass)
      custom_methods[name] = klass
    end

    # Register a database to compile migrations for.
    def register_database(name, config = {})
      multi_db_config.register(name, config)
    end


    # Setter for backward compatibility with v1.x single-database configurations
    # Only works when using the legacy configuration style (not register_database)
    def lockfile_path=(path)
      # This setter only works with single-database config for backward compatibility
      # For multi-database, use register_database with lockfile_path option
      if databases.default
        databases.default.lockfile_path = path
      else
        raise ArgumentError, "lockfile_path= is only for backward compatibility. " \
                           "Use register_database with lockfile_path option instead."
      end
    end

    # Explicitly define getters for backwards compatibility when the database isnt specified.
    # rubocop:disable Layout/LineLength
    def migration_directory(database_name = nil) = config(database_name).migration_directory
    def output_directory(database_name = nil) = config(database_name).output_directory
    def lockfile_path(database_name = nil) = config(database_name).lockfile_path
    def access_exclusive_lock_timeout(database_name = nil) = config(database_name).access_exclusive_lock_timeout
    def access_exclusive_lock_timeout_limit(database_name = nil) = config(database_name).access_exclusive_lock_timeout_limit
    def access_exclusive_statement_timeout(database_name = nil) = config(database_name).access_exclusive_statement_timeout
    def access_exclusive_statement_timeout_limit(database_name = nil) = config(database_name).access_exclusive_statement_timeout_limit
    def concurrent_lock_timeout_limit(database_name = nil) = config(database_name).concurrent_lock_timeout_limit
    def concurrent_statement_timeout_limit(database_name = nil) = config(database_name).concurrent_statement_timeout_limit
    # rubocop:enable Layout/LineLength

    # Delegate setter methods to the default database for backwards compatibility
    delegate :migration_directory=,
             :output_directory=,
             :access_exclusive_lock_timeout=,
             :access_exclusive_lock_timeout_limit=,
             :access_exclusive_statement_timeout=,
             :access_exclusive_statement_timeout_limit=,
             :concurrent_lock_timeout_limit=,
             :concurrent_statement_timeout_limit=,
             to: :default

    delegate :validate!, :default, :config, to: :databases

    alias_method :database, :config

    def databases
      # If we've never registered any databases, use a single database with
      # default values for backwards compatibility.
      @multi_db_config.nil? ? single_db_config : @multi_db_config
    end

    def validate!
      if @single_db_config && @multi_db_config
        raise ArgumentError, "Cannot use multi and single database config. Config setters are now deprecated, " \
                             "use only `register_database(name, config)` to configure Nandi."
      end
      databases.validate!
    end

    private

    def single_db_config
      # Pre-register the default database to ensure behavior is backwards compatible.
      @single_db_config ||= begin
        single_db_config = MultiDatabase.new
        single_db_config.register(:primary, {})
        single_db_config
      end
    end

    def multi_db_config
      @multi_db_config ||= MultiDatabase.new
    end
  end
end
