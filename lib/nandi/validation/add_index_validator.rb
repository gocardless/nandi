# frozen_string_literal: true

require "nandi/validation/instruction_validator"

module Nandi
  module Validation
    class AddIndexValidator < InstructionValidator
      def call
        assert(
          not_using_hash_index?,
          "add_index: Nandi does not support hash indexes. Hash indexes typically have " \
          "very specialized use cases. Please revert to using a btree index, or proceed " \
          "with the creation of this index without using Nandi.",
        )
      end

      private

      def not_using_hash_index?
        instruction.extra_args[:using] != :hash
      end
    end
  end
end
