# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class EachValidator
      include Nandi::Validation::FailureHelpers

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        case instruction.procedure
        when :remove_index
          RemoveIndexValidator.call(instruction)
        when :add_column
          AddColumnValidator.call(instruction)
        when :add_reference
          AddReferenceValidator.call(instruction)
        else
          success
        end
      end

      attr_reader :instruction
    end
  end
end
