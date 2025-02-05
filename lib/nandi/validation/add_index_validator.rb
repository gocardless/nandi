# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class AddIndexValidator
      include Nandi::Validation::FailureHelpers

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        assert(
          not_using_hash_index?,
          "add_index: Nandi does not support hash indexes. Hash indexes typically have " \
          "very specialized use cases. Please revert to using a btree index, or proceed " \
          "with the creation of this index without using Nandi.",
        )
      end

      attr_reader :instruction

      private

      def not_using_hash_index?
        instruction.extra_args[:using] != :hash
      end
    end
  end
end
