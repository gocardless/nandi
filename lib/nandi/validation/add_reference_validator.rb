# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class AddReferenceValidator
      include Nandi::Validation::FailureHelpers

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        foreign_key = instruction.extra_args.fetch(:foreign_key) { false }

        assert(
          !foreign_key,
          foreign_key_message,
        )
      end

      private

      def foreign_key_message
        "Adding a foreign key constraint must be done in two separate migrations. " \
          "Use the `add_foreign_key` and `validate_foreign_key` methods, or the " \
          "nandi:foreign_key generator, to do this."
      end

      attr_reader :instruction
    end
  end
end
