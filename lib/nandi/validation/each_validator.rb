# frozen_string_literal: true

require "nandi/validation/instruction_validator"

module Nandi
  module Validation
    class EachValidator < InstructionValidator
      def call
        return success unless instruction.respond_to?(:validator)

        instruction.validator.call(instruction, db_config.name)
      end
    end
  end
end
