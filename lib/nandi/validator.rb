# frozen_string_literal: true

require "pry"

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
        _, opts = instruction.arguments

        opts.key?(:name) || opts.key?(:column)
      end
    end

    def self.call(instructions)
      new(instructions).call
    end

    def initialize(instructions)
      @instructions = instructions
    end

    def call
      new_indexes_are_separated_from_other_migrations && each_instruction_is_valid
    end

    private

    def new_indexes_are_separated_from_other_migrations
      instructions.none? { |i| i.procedure == :create_index } ||
        instructions.count == 1
    end

    def each_instruction_is_valid
      instructions.each do |instruction|
        case instruction.procedure
        when :drop_index
          return false unless DropIndexValidator.call(instruction)
        end
      end

      true
    end

    attr_reader :instructions
  end
end
