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
        return success unless instruction.respond_to?(:validator)

        instruction.validator.call(instruction)
      end

      attr_reader :instruction
    end
  end
end
