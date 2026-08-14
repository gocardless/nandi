# frozen_string_literal: true

require "nandi/validation/instruction_validator"

module Nandi
  module Validation
    class EachValidator < InstructionValidator

      def call
        case instruction.procedure
        when :add_index
          AddIndexValidator.call(instruction, db_config.name)
        when :remove_index
          RemoveIndexValidator.call(instruction, db_config.name)
        when :add_column
          AddColumnValidator.call(instruction, db_config.name)
        when :add_reference
          AddReferenceValidator.call(instruction, db_config.name)
        else
          success
        end
      end

    end
  end
end
