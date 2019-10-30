# frozen_string_literal: true

require "dry/monads"
require "nandi/validation"
require "nandi/timeout_policies"

module Nandi
  class Validator
    include Nandi::Validation::FailureHelpers

    class InstructionValidator
      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        raise NotImplementedError
      end

      attr_reader :instruction
    end

    def self.call(migration)
      new(migration).call
    end

    def initialize(migration)
      @migration = migration
    end

    def call
      migration_invariants_respected << each_instruction_validation
    end

    private

    def migration_invariants_respected
      Validation::Result.new.tap do |result|
        result << assert(
          at_most_one_object_modified,
          "modifying more than one table per migration",
        )

        result << assert(
          new_indexes_are_separated_from_other_migrations,
          "creating more than one index per migration",
        )

        result << validate_timeouts
      end
    end

    def at_most_one_object_modified
      [migration.up_instructions, migration.down_instructions].all? do |instructions|
        affected_tables = instructions.map do |instruction|
          instruction.respond_to?(:table) && instruction.table.to_sym
        end

        affected_tables.uniq.count <= 1
      end
    end

    def new_indexes_are_separated_from_other_migrations
      [migration.up_instructions, migration.down_instructions].map do |instructions|
        instructions.none? { |i| i.procedure == :add_index } ||
          instructions.count == 1
      end.all?
    end

    def statement_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.statement_timeout <=
          Nandi.config.access_exclusive_statement_timeout_limit
    end

    def lock_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.lock_timeout <=
          Nandi.config.access_exclusive_lock_timeout_limit
    end

    def each_instruction_validation
      instructions.inject(success) do |result, instruction|
        collect_errors(Validation::EachValidator.call(instruction), result)
      end
    end

    def validate_timeouts
      Nandi::Validation::TimeoutValidator.call(migration)
    end

    def instructions
      [*migration.up_instructions, *migration.down_instructions]
    end

    attr_reader :migration
  end
end
