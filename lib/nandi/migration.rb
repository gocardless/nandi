# frozen_string_literal: true

require "nandi/migration/abstract_base"
require "nandi/instructions"

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
  class Migration < AbstractBaseMigration
    # Avoids a circular dependency as we want Nandi::Migration to inherit from Nandi::Migration::AbstractBase
    AbstractBase = AbstractBaseMigration

    # Use this declaration instead of Migration::Postgres so existing migrations default to using the Postgres adapter
    # without naming changes
    Postgres = self # rubocop:disable Naming/ConstantName

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

    #
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
  end
end
