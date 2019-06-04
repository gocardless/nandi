# frozen_string_literal: true

require "nandi/instructions"
require "nandi/validator"

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
    module LockWeights
      ACCESS_EXCLUSIVE = 1
      SHARE = 0
    end

    class InstructionSet < SimpleDelegator
      def strictest_lock
        map { |i| i.respond_to?(:lock) ? i.lock : LockWeights::ACCESS_EXCLUSIVE }.max
      end
    end

    class << self
      # The current lock timeout.
      def lock_timeout
        @lock_timeout ||= Nandi.config.lock_timeout
      end

      # The current statement timeout.
      def statement_timeout
        @statement_timeout ||= Nandi.config.statement_timeout
      end

      # For sake both of correspondence with Postgres syntax and familiarity
      # with ActiveRecord's identically named macros, we disable this cop.

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
      # rubocop:enable Naming/AccessorMethodName
    end

    # @param validator [Nandi::Validator]
    def initialize(validator)
      @validator = validator
      @instructions = Hash.new { |h, k| h[k] = InstructionSet.new([]) }
    end

    # @api private
    def up_instructions
      compile_instructions(:up)
    end

    # @api private
    def down_instructions
      compile_instructions(:down)
    end

    def lock_timeout
      self.class.lock_timeout
    end

    def statement_timeout
      self.class.statement_timeout
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
    # * use the `BTREE` index type which is the safest to create.
    #
    # Because index creation is particularly failure-prone, and because
    # we cannot run in a transaction and therefore risk partially applied
    # migrations that (in a Rails environment) require manual intervention,
    # Nandi Validates that, if there is a create_index statement in the
    # migration, it must be the only statement.
    # @param table [Symbol, String] The name of the table to add the index to
    # @param fields [Symbol, String, Array] The field or fields to use in the
    #   index
    # @param kwargs [Hash] Arbitrary options to pass to the backend adapter.
    #   Attempts to remove `CONCURRENTLY` or change the index type will be ignored.
    def create_index(table, fields, **kwargs)
      current_instructions << Instructions::CreateIndex.new(
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
    # intervention, Nandi Validates that, if there is a drop_index statement
    # in the migration, it must be the only statement.
    # @param table [Symbol, String] The name of the table to add the index to
    # @param target [Symbol, String, Array, Hash] This can be either the field (or
    #   array of fields) in the index to be dropped, or a hash of options, which
    #   must include either a `column` key (which is the same: a field or list
    #   of fields) or a `name` key, which is the name of the index to be dropped.
    def drop_index(table, target)
      current_instructions << Instructions::DropIndex.new(table: table, field: target)
    end

    # Creates a new table. Yields a ColumnsReader object as a block, to allow adding
    # columns.
    # @example
    #   create_table :widgets do |t|
    #     t.column :foo, :text, default: true
    #   end
    # @param table [String, Symbol] The name of the new table
    # @yieldparam columns_reader [Nandi::Instructions::CreateTable::ColumnsReader]
    def create_table(table, &block)
      current_instructions << Instructions::CreateTable.new(
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

    # Remove an existing column.
    # @param table [Symbol, String] The name of the table to remove the column
    #   from.
    # @param name [Symbol, String] The name of the column
    # @param extra_args [Hash] Arbitrary options to be passed to the backend.
    def drop_column(table, name, **extra_args)
      current_instructions << Instructions::DropColumn.new(
        **extra_args,
        table: table,
        name: name,
      )
    end

    # Alter an existing column. Nandi will validate that you are not doing
    # any of the following unsafe operations:
    # * Adding a NOT NULL constraint
    # * Adding a UNIQUE constraint
    # * Changing the type of the column
    # @param table [Symbol, String] The name of the table with the target column
    # @param name [Symbol, String] The name of the column
    # @param alterations [Hash] Hash of values to represent changes to the column.
    # @example
    #   alter_column :widgets, :foo, collation: :de_DE
    def alter_column(table, name, **alterations)
      current_instructions << Instructions::AlterColumn.new(
        **alterations,
        table: table,
        name: name,
      )
    end

    # Add a foreign key constraint. The generated SQL will include the NOT VALID
    # parameter, which will prevent immediate validation of the constraint, which
    # locks the target table for writes potentially for a long time. Use the separate
    # #validate_foreign_key method, in a separate migration; this only takes a row-level
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

    # Validates an existing foreign key constraint.
    # @param table [Symbol, String] The name of the table with the constraint
    # @param name [Symbol, String] The name of the constraint
    def validate_foreign_key(table, name)
      current_instructions << Instructions::ValidateForeignKey.new(
        table: table,
        name: name,
      )
    end

    # Drops an existing foreign key constraint.
    # @param table [Symbol, String] The name of the table with the constraint
    # @param name [Symbol, String] The name of the constraint
    def drop_foreign_key(table, name)
      current_instructions << Instructions::DropForeignKey.new(
        table: table,
        name: name,
      )
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
      Validation::Result.new << e.message
    end

    def name
      self.class.name
    end

    def respond_to_missing?(name)
      Nandi.config.custom_methods.key?(name) || super
    end

    def mixins
      (up_instructions + down_instructions).inject([]) do |mixins, i|
        i.respond_to?(:mixins) ? [*mixins, *i.mixins] : mixins
      end.uniq
    end

    def method_missing(name, *args, &block)
      if Nandi.config.custom_methods.key?(name)
        invoke_custom_method(name, *args, &block)
      else
        super
      end
    end

    private

    attr_reader :validator

    def current_instructions
      @instructions[@direction]
    end

    def invoke_custom_method(name, *args, &block)
      klass = Nandi.config.custom_methods[name]
      current_instructions << klass.new(*args, &block)
    end
  end
end
