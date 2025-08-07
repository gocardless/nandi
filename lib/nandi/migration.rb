# frozen_string_literal: true

require "nandi/instructions"
require "nandi/validator"
require "nandi/validation/failure_helpers"

module Nandi
  # @abstract A migration must implement #up (the forward migration), and may
  #   also implement #down (the rollback sequence).
  # The base class for migrations; Nandi's equivalent of ActiveRecord::Migration.
  # All the statements in the migration are statically analysed together to rule
  # out migrations with a high risk of causing availability issues. Additionally,
  # our implementations of some statements will rule out certain common footguns
  # (for example, creating an index without using the `CONCURRENTLY` parameter.)
  # @example
  #     class CreateWidgetsTable < Nandi::Migration
  #       def up
  #         create_table :widgets do |t|
  #           t.column :weight, :number
  #           t.column :name, :text, default: "Unknown widget"
  #         end
  #       end
  #
  #       def down
  #         drop_table :widgets
  #       end
  #     end
  class Migration
    include Nandi::Validation::FailureHelpers

    module LockWeights
      ACCESS_EXCLUSIVE = 1
      SHARE = 0
    end

    class InstructionSet < SimpleDelegator
      def strictest_lock
        return LockWeights::SHARE if empty?

        map { |i| i.respond_to?(:lock) ? i.lock : LockWeights::ACCESS_EXCLUSIVE }.max
      end
    end

    class << self
      attr_reader :lock_timeout, :statement_timeout, :target_database

      # For sake both of correspondence with Postgres syntax and familiarity
      # with activerecord-safe_migrations's identically named macros, we
      # disable this cop.

      # rubocop:disable Naming/AccessorMethodName

      # Override the default lock timeout for the duration of the migration.
      # This may be helpful when making changes to very busy tables, when a
      # lock is less likely to be immediately available.
      # @param timeout [Integer] New lock timeout in ms
      def set_lock_timeout(timeout)
        @lock_timeout = timeout
      end

      # Override the default statement timeout for the duration of the migration.
      # This may be helpful when making changes that are likely to take a lot
      # of time, like adding a new index on a large table.
      # @param timeout [Integer] New lock timeout in ms
      def set_statement_timeout(timeout)
        @statement_timeout = timeout
      end

      # Set the target database for this migration
      # @param db_name [Symbol] Database identifier
      def database(db_name)
        @target_database = db_name
      end
      # rubocop:enable Naming/AccessorMethodName
    end

    # @param validator [Nandi::Validator]
    def initialize(validator)
      @validator = validator
      @instructions = Hash.new { |h, k| h[k] = InstructionSet.new([]) }
      validate
    end

    # @api private
    def up_instructions
      compile_instructions(:up)
    end

    # @api private
    def down_instructions
      compile_instructions(:down)
    end

    # The current lock timeout.
    def lock_timeout
      self.class.lock_timeout || default_lock_timeout
    end

    # The current statement timeout.
    def statement_timeout
      self.class.statement_timeout || default_statement_timeout
    end

    # @api private
    def strictest_lock
      @instructions.values.map(&:strictest_lock).max
    end

    # @abstract
    def up
      raise NotImplementedError
    end

    def down; end

    # Adds a new index to the database.
    #
    # Nandi will:
    # * add the `CONCURRENTLY` option, which means the change takes a less
    #   restrictive lock at the cost of not running in a DDL transaction
    # * default to the `BTREE` index type, as it is commonly a good fit.
    #
    # Because index creation is particularly failure-prone, and because
    # we cannot run in a transaction and therefore risk partially applied
    # migrations that (in a Rails environment) require manual intervention,
    # Nandi Validates that, if there is a add_index statement in the
    # migration, it must be the only statement.
    # @param table [Symbol, String] The name of the table to add the index to
    # @param fields [Symbol, String, Array] The field or fields to use in the
    #   index
    # @param kwargs [Hash] Arbitrary options to pass to the backend adapter.
    #   Attempts to remove `CONCURRENTLY` or change the index type will be ignored.
    def add_index(table, fields, **kwargs)
      current_instructions << Instructions::AddIndex.new(
        **kwargs,
        table: table,
        fields: fields,
      )
    end

    # Drop an index from the database.
    #
    # Nandi will add the `CONCURRENTLY` option, which means the change
    # takes a less restrictive lock at the cost of not running in a DDL
    # transaction.
    #
    # Because we cannot run in a transaction and therefore risk partially
    # applied migrations that (in a Rails environment) require manual
    # intervention, Nandi Validates that, if there is a remove_index statement
    # in the migration, it must be the only statement.
    # @param table [Symbol, String] The name of the table to add the index to
    # @param target [Symbol, String, Array, Hash] This can be either the field (or
    #   array of fields) in the index to be dropped, or a hash of options, which
    #   must include either a `column` key (which is the same: a field or list
    #   of fields) or a `name` key, which is the name of the index to be dropped.
    def remove_index(table, target)
      current_instructions << Instructions::RemoveIndex.new(table: table, field: target)
    end

    # Creates a new table. Yields a ColumnsReader object as a block, to allow adding
    # columns.
    # @example
    #   create_table :widgets do |t|
    #     t.text :foo, default: true
    #   end
    # @param table [String, Symbol] The name of the new table
    # @yieldparam columns_reader [Nandi::Instructions::CreateTable::ColumnsReader]
    def create_table(table, **kwargs, &block)
      current_instructions << Instructions::CreateTable.new(
        **kwargs,
        table: table,
        columns_block: block,
      )
    end

    # Drops an existing table
    # @param table [String, Symbol] The name of the table to drop.
    def drop_table(table)
      current_instructions << Instructions::DropTable.new(table: table)
    end

    # Adds a new column. Nandi will explicitly set the column to be NULL,
    # as validating a new NOT NULL constraint can be very expensive on large
    # tables and cause availability issues.
    # @param table [Symbol, String] The name of the table to add the column to
    # @param name [Symbol, String] The name of the column
    # @param type [Symbol, String] The type of the column
    # @param kwargs [Hash] Arbitrary options to be passed to the backend.
    def add_column(table, name, type, **kwargs)
      current_instructions << Instructions::AddColumn.new(
        table: table,
        name: name,
        type: type,
        **kwargs,
      )
    end

    # Adds a new reference column. Nandi will validate that the foreign key flag
    # is not set to true; use `add_foreign_key` and `validate_foreign_key` instead!
    # @param table [Symbol, String] The name of the table to add the column to
    # @param ref_name [Symbol, String] The referenced column name
    # @param kwargs [Hash] Arbitrary options to be passed to the backend.
    def add_reference(table, ref_name, **kwargs)
      current_instructions << Instructions::AddReference.new(
        table: table,
        ref_name: ref_name,
        **kwargs,
      )
    end

    # Removes a reference column.
    # @param table [Symbol, String] The name of the table to remove the reference from
    # @param ref_name [Symbol, String] The referenced column name
    # @param kwargs [Hash] Arbitrary options to be passed to the backend.
    def remove_reference(table, ref_name, **kwargs)
      current_instructions << Instructions::RemoveReference.new(
        table: table,
        ref_name: ref_name,
        **kwargs,
      )
    end

    # Remove an existing column.
    # @param table [Symbol, String] The name of the table to remove the column
    #   from.
    # @param name [Symbol, String] The name of the column
    # @param extra_args [Hash] Arbitrary options to be passed to the backend.
    def remove_column(table, name, **extra_args)
      current_instructions << Instructions::RemoveColumn.new(
        **extra_args,
        table: table,
        name: name,
      )
    end

    # Add a foreign key constraint. The generated SQL will include the NOT VALID
    # parameter, which will prevent immediate validation of the constraint, which
    # locks the target table for writes potentially for a long time. Use the separate
    # #validate_constraint method, in a separate migration; this only takes a row-level
    # lock as it scans through.
    # @param table [Symbol, String] The name of the table with the reference column
    # @param target [Symbol, String] The name of the referenced table
    # @param column [Symbol, String] The name of the reference column. If omitted, will
    #   default to the singular of target + "_id"
    # @param name [Symbol, String] The name of the constraint to create. Defaults to
    #   table_target_fk
    def add_foreign_key(table, target, column: nil, name: nil)
      current_instructions << Instructions::AddForeignKey.new(
        table: table,
        target: target,
        column: column,
        name: name,
      )
    end

    # Add a check constraint, in the NOT VALID state.
    # @param table [Symbol, String] The name of the table with the column
    # @param name [Symbol, String] The name of the constraint to create
    # @param check [Symbol, String] The predicate to check
    def add_check_constraint(table, name, check)
      current_instructions << Instructions::AddCheckConstraint.new(
        table: table,
        name: name,
        check: check,
      )
    end

    # Validates an existing foreign key constraint.
    # @param table [Symbol, String] The name of the table with the constraint
    # @param name [Symbol, String] The name of the constraint
    def validate_constraint(table, name)
      current_instructions << Instructions::ValidateConstraint.new(
        table: table,
        name: name,
      )
    end

    # Drops an existing constraint.
    # @param table [Symbol, String] The name of the table with the constraint
    # @param name [Symbol, String] The name of the constraint
    def drop_constraint(table, name)
      current_instructions << Instructions::DropConstraint.new(
        table: table,
        name: name,
      )
    end

    # Drops an existing NOT NULL constraint. Please note that this migration is
    # not safely reversible; to enforce NOT NULL like behaviour, use a CHECK
    # constraint and validate it in a separate migration.
    # @param table [Symbol, String] The name of the table with the constraint
    # @param column [Symbol, String] The name of the column to remove NOT NULL
    #   constraint from
    def remove_not_null_constraint(table, column)
      current_instructions << Instructions::RemoveNotNullConstraint.new(
        table: table,
        column: column,
      )
    end

    # Changes the default value for this column when new rows are inserted into
    # the table.
    # @param table [Symbol, String] The name of the table with the column
    # @param column [Symbol, String] The name of the column to change
    # @param value [Object] The new default value
    def change_column_default(table, column, value)
      current_instructions << Instructions::ChangeColumnDefault.new(
        table: table,
        column: column,
        value: value,
      )
    end

    # Raises an `ActiveRecord::IrreversibleMigration` error for use in
    # irreversible migrations
    def irreversible_migration
      current_instructions << Instructions::IrreversibleMigration.new
    end

    # @api private
    def compile_instructions(direction)
      @direction = direction

      public_send(direction) unless current_instructions.any?

      current_instructions
    end

    # @api private
    def validate
      validator.call(self)
    rescue NotImplementedError => e
      Validation::Result.new << failure(e.message)
    end

    def disable_lock_timeout?
      if self.class.lock_timeout.nil?
        strictest_lock == LockWeights::SHARE
      else
        false
      end
    end

    def disable_statement_timeout?
      if self.class.statement_timeout.nil?
        strictest_lock == LockWeights::SHARE
      else
        false
      end
    end

    def name
      self.class.name
    end

    # Get the target database for this migration
    # @return [Symbol, nil] Database identifier
    def target_database
      self.class.target_database
    end

    def respond_to_missing?(name)
      Nandi.config.custom_methods.key?(name) || super
    end

    def mixins
      (up_instructions + down_instructions).inject([]) do |mixins, i|
        i.respond_to?(:mixins) ? [*mixins, *i.mixins] : mixins
      end.uniq
    end

    def method_missing(name, ...)
      if Nandi.config.custom_methods.key?(name)
        invoke_custom_method(name, ...)
      else
        super
      end
    end

    private

    attr_reader :validator

    def current_instructions
      @instructions[@direction]
    end

    def default_statement_timeout
      Nandi.config.access_exclusive_statement_timeout
    end

    def default_lock_timeout
      Nandi.config.access_exclusive_lock_timeout
    end

    def invoke_custom_method(name, ...)
      klass = Nandi.config.custom_methods[name]
      current_instructions << klass.new(...)
    end
  end
end
