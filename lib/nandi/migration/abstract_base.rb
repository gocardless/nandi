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
  class AbstractBaseMigration
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
      attr_reader :lock_timeout, :statement_timeout

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
      # rubocop:enable Naming/AccessorMethodName
    end

    # @param validator [Nandi::Validator]
    def initialize(validator, database_name: nil)
      @validator = validator
      @database_name = database_name
      @instructions = Hash.new { |h, k| h[k] = InstructionSet.new([]) }
      validate
    end

    # @api private
    attr_reader :database_name

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

    # Raises an `ActiveRecord::IrreversibleMigration` error for use in
    # irreversible migrations
    def irreversible_migration
      current_instructions << Instructions::IrreversibleMigration.new
    end

    # @api private
    def compile_instructions(direction)
      @direction = direction

      public_send(direction) unless current_instructions.any?

      Nandi.config.migration_modifiers.each { |mod| mod.public_send(direction, current_instructions) }

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
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_lock_timeout(database_name, table).nil?
      else
        false
      end
    end

    def disable_statement_timeout?
      if self.class.statement_timeout.nil?
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_statement_timeout(database_name, table).nil?
      else
        false
      end
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
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_statement_timeout(database_name, table) ||
          Nandi.config.access_exclusive_statement_timeout(database_name)
      else
        Nandi.config.access_exclusive_statement_timeout(database_name)
      end
    end

    def default_lock_timeout
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_lock_timeout(database_name, table) ||
          Nandi.config.access_exclusive_lock_timeout(database_name)
      else
        Nandi.config.access_exclusive_lock_timeout(database_name)
      end
    end

    # The table this migration modifies, if any. Validator guarantees a migration
    # modifies at most one table, so this is unambiguous.
    def table
      instruction_with_table = all_instructions.find { |i| i.respond_to?(:table) }
      instruction_with_table&.table&.to_sym
    end

    def all_instructions
      up_instructions + down_instructions
    end

    def invoke_custom_method(name, ...)
      klass = Nandi.config.custom_methods[name]
      current_instructions << klass.new(...)
    end
  end
end
