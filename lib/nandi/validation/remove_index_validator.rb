# frozen_string_literal: true

require "nandi/validation/instruction_validator"

module Nandi
  module Validation
    class RemoveIndexValidator < InstructionValidator
      def call
        opts = instruction.extra_args

        assert(
          opts.key?(:name) || opts.key?(:column),
          "remove_index: requires a `name` or `column` argument",
        )
      end
    end
  end
end
