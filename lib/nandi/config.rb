# frozen_string_literal: true

require "nandi/renderers"

module Nandi
  class Config
    DEFAULT_LOCK_TIMEOUT = 5_000
    # Most DDL changes take a very strict lock, but execute very quickly. For these
    # the statement timeout should be very tight, so that if there's an unexpected
    # delay the query queue does not back up.
    #
    # However, some operations are very slow but take locks that do not impact
    # database availability - for instance, adding an index concurrently, which will
    # take an extremely unpredictable amount of time to finish. Our default for these
    # statements is much higher.
    DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT = 1_500
    DEFAULT_STATEMENT_TIMEOUT = 10_800_000 # 3 hours
    DEFAULT_COMPILE_FILES = "all"

    DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT =
      DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
    DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT = DEFAULT_LOCK_TIMEOUT
    DEFAULT_CONCURRENT_STATEMENT_TIMEOUT_LIMIT = 3_600_000 # 1 hour

    # The rendering backend used to produce output. The only supported option
    # at current is Nandi::Renderers::ActiveRecord, which produces ActiveRecord
    # migrations.
    # @return [Class]
    attr_accessor :renderer

    # The default lock timeout for migrations. Can be overridden by way of the
    # `set_lock_timeout` class method in a given migration. Default: 5,000ms.
    # @return [Integer]
    attr_accessor :lock_timeout

    # The default statement timeout for migrations that take permissive locks.
    # Can be overridden by way of the `set_statement_timeout` class method in a
    # given migration. Default: 10,800,000ms (ie, 3 hours).
    # @return [Integer]
    attr_accessor :statement_timeout

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

    # The directory for Nandi migrations. Default: `db/safe_migrations`
    # @return [String]
    attr_accessor :migration_directory

    # The directory for output files. Default: `db/migrate`
    # @return [String]
    attr_accessor :output_directory

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
      @lock_timeout = DEFAULT_LOCK_TIMEOUT
      @statement_timeout = DEFAULT_STATEMENT_TIMEOUT
      @concurrent_statement_timeout_limit = DEFAULT_CONCURRENT_STATEMENT_TIMEOUT_LIMIT
      @access_exclusive_statement_timeout = DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT
      @custom_methods = {}
      @access_exclusive_statement_timeout_limit =
        DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT
      @access_exclusive_lock_timeout_limit = DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT
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
  end
end
