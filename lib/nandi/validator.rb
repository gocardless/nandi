# frozen_string_literal: true

require "nandi/each_validator"

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

    class DropIndexValidator < InstructionValidator
      def call
        instruction.extra_args.key?(:name) || instruction.extra_args.key?(:column)
      end
    end

    def self.call(instructions)
      new(instructions).call
    end

    def initialize(instructions)
      @instructions = instructions
    end

    def call
      at_most_one_object_modified &&
        new_indexes_are_separated_from_other_migrations &&
        each_instruction_is_valid
    end

    private

    def at_most_one_object_modified
      instructions.map(&:table).map(&:to_sym).uniq.count <= 1
    end

    def new_indexes_are_separated_from_other_migrations
      instructions.none? { |i| i.procedure == :create_index } ||
        instructions.count == 1
    end

    def each_instruction_is_valid
      instructions.all? { |instruction| EachValidator.call(instruction) }
    end

    attr_reader :instructions
  end
end
