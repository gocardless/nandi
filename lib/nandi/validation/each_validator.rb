# frozen_string_literal: true

module Nandi
  module Validation
    class EachValidator
      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        result = Result.new
        case instruction.procedure
        when :remove_index
          result.merge(RemoveIndexValidator.call(instruction))
        when :add_column
          result.merge(AddColumnValidator.call(instruction))
        when :change_column
          result.merge(ChangeColumnValidator.call(instruction))
        end
        result
      end

      attr_reader :instruction
    end
  end
end
