# frozen_string_literal: true

module Nandi
  module Validation
    class AddColumnValidator
      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        nullable? && no_default? && not_unique?
      end

      attr_reader :instruction

      private

      def nullable?
        instruction.extra_args[:null]
      end

      def no_default?
        !instruction.extra_args.key?(:default)
      end

      def not_unique?
        !instruction.extra_args.fetch(:unique, false)
      end
    end
  end
end
