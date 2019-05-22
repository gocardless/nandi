# frozen_string_literal: true

require "nandi/validation"

module Nandi
  class Validator
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
      migration_invariants_respected.merge(each_instruction_validation)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def migration_invariants_respected
      Validation::Result.new(@instruction).tap do |result|
        unless at_most_one_object_modified
          result << "modifying more than one table per migragrion"
        end
        unless new_indexes_are_separated_from_other_migrations
          result << "creating more than one index per migration"
        end
        unless statement_timeout_is_within_acceptable_bounds
          result << <<~MSG
            statement timeout too high for a migration that needs
            ACCESS EXCLUSIVE lock
          MSG
        end
        unless lock_timeout_is_within_acceptable_bounds
          result << <<~MSG
            lock timeout too high for a migration that needs
            ACCESS EXCLUSIVE lock
          MSG
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def at_most_one_object_modified
      [migration.up_instructions, migration.down_instructions].map do |instructions|
        instructions.map(&:table).map(&:to_sym).uniq.count <= 1
      end.all?
    end

    def new_indexes_are_separated_from_other_migrations
      [migration.up_instructions, migration.down_instructions].map do |instructions|
        instructions.none? { |i| i.procedure == :create_index } ||
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
      instructions = migration.up_instructions + migration.down_instructions

      instructions.inject(Validation::Result.new) do |result, instruction|
        result.merge(Validation::EachValidator.call(instruction))
      end
    end

    attr_reader :migration
  end
end
