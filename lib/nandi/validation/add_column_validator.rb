# frozen_string_literal: true

require "nandi/validation/instruction_validator"

module Nandi
  module Validation
    class AddColumnValidator < InstructionValidator
      def call
        collect_errors(
          assert(nullable? || default_value?,
                 "add_column: non-null column lacks default"),
          assert(!unique?, "add_column: column is unique"),
        )
      end

      private

      def default_value?
        !instruction.extra_args[:default].nil?
      end

      def nullable?
        instruction.extra_args.fetch(:null, true)
      end

      def unique?
        instruction.extra_args.fetch(:unique, false)
      end
    end
  end
end
