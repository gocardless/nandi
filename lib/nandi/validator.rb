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

    def self.call(instructions)
      new(instructions).call
    end

    def initialize(instructions)
      @instructions = instructions
    end

    def call
      Validation::Result.new(@instruction).tap do |result|
        unless at_most_one_object_modified
          result << "modifying more than one table per migragrion"
        end
        unless new_indexes_are_separated_from_other_migrations
          result << "creating more than one index per migration"
        end
        result.merge(each_instruction_validation)
      end
    end

    private

    def at_most_one_object_modified
      instructions.map(&:table).map(&:to_sym).uniq.count <= 1
    end

    def new_indexes_are_separated_from_other_migrations
      instructions.none? { |i| i.procedure == :create_index } ||
        instructions.count == 1
    end

    def each_instruction_validation
      instructions.inject(Validation::Result.new) do |result, instruction|
        result.merge(Validation::EachValidator.call(instruction))
      end
    end

    attr_reader :instructions
  end
end
