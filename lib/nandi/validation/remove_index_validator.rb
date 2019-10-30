# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class RemoveIndexValidator
      include Nandi::Validation::FailureHelpers

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        opts = instruction.extra_args

        assert(
          opts.key?(:name) || opts.key?(:column),
          "remove_index: requires a `name` or `column` argument",
        )
      end

      attr_reader :instruction
    end
  end
end
