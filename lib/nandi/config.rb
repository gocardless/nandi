# frozen_string_literal: true

require "nandi/renderers"
require "nandi/lockfile"
require "nandi/multi_database"

module Nandi
  class Config
    # Most DDL changes take a very strict lock, but execute very quickly. For these
    # the statement timeout should be very tight, so that if there's an unexpected
    # delay the query queue does not back up.
    DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT = 1_500
    DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT = 5_000

    DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT =
      DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
    DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT =
      DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT
    DEFAULT_LOCKFILE_DIRECTORY = File.join(Dir.pwd, "db")
    DEFAULT_CONCURRENT_TIMEOUT_LIMIT = 3_600_000
    DEFAULT_COMPILE_FILES = "all"

    DEFAULT_MIGRATION_DIRECTORY = "db/safe_migrations"
    DEFAULT_OUTPUT_DIRECTORY = "db/migrate"

    # The rendering backend used to produce output. The only supported option
    # at current is Nandi::Renderers::ActiveRecord, which produces ActiveRecord
    # migrations.
    # @return [Class]
    attr_accessor :renderer

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

    # The directory for Nandi migrations. Default: `db/safe_migrations`.
    # @return [String]
    attr_writer :migration_directory

    # The directory for output files. Default: `db/migrate`
    # @return [String]
    attr_writer :output_directory

    # The files to compile when the compile generator is run. Default: `all`
    # May be one of the following:
    # - 'all' compiles all files
    # - 'git-diff' only files changed since last commit
    # - a full or partial version timestamp, eg '20190101010101', '20190101'
    # - a timestamp range , eg '>=20190101010101'
    # @return [String]
    attr_accessor :compile_files
    #
    # Directory where .nandilock.yml will be stored
    # Defaults to project root
    # @return [String]
    attr_writer :lockfile_directory

    # @api private
    attr_reader :post_processor, :custom_methods

    def initialize(renderer: Renderers::ActiveRecord)
      @renderer = renderer
      @access_exclusive_statement_timeout = DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
      @concurrent_lock_timeout_limit =
        @concurrent_statement_timeout_limit =
          DEFAULT_CONCURRENT_TIMEOUT_LIMIT
      @custom_methods = {}
      @access_exclusive_lock_timeout =
        DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT
      @access_exclusive_statement_timeout =
        DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
      @access_exclusive_statement_timeout_limit =
        DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT
      @access_exclusive_lock_timeout_limit = DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT
      @compile_files = DEFAULT_COMPILE_FILES
      @lockfile_directory = DEFAULT_LOCKFILE_DIRECTORY
      @multi_database = Nandi::MultiDatabase.new
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

    def register_database(name, config)
      @multi_database.register(name, config)
    end

    def database_names
      @multi_database.names if @multi_database.enabled?
    end

    def lockfile_path(database_name = nil)
      File.join(lockfile_directory, lockfile_name(database_name))
    end

    def migration_directory(database_name = nil)
      return @migration_directory || DEFAULT_MIGRATION_DIRECTORY if !@multi_database.enabled?

      @multi_database.config(database_name).migration_directory
    end

    def output_directory(database_name = nil)
      return @output_directory || DEFAULT_OUTPUT_DIRECTORY if !@multi_database.enabled?

      @multi_database.config(database_name).output_directory
    end

    def validate!
      enforce_exclusive_mode!
      @multi_database.validate!
    end

    delegate :enabled?, to: :@multi_database, prefix: :multi_database

    private

    def lockfile_directory
      @lockfile_directory ||= Pathname.new(@lockfile_directory)
    end

    def lockfile_name(database_name)
      return ".nandilock.yml" if !@multi_database.enabled?

      @multi_database.config(database_name).lockfile_name
    end

    def enforce_exclusive_mode!
      # We should only be either registering databases (multi-database mode) or overriding
      # the default configuration (single-database mode), not both.
      if multi_database_enabled? && (@migration_directory.present? || @output_directory.present?)
        raise ArgumentError, "Cannot specify both `databases` and `migration_directory`/`output_directory`"
      end
    end
  end
end
