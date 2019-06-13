# frozen_string_literal: true

module Nandi
  module Validation
    class ChangeColumnValidator
      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        Result.new(@instruction).tap do |result|
          result << "adding null constraint" if adding_not_null_contraint?
          result << "adding unique constraint" if adding_unique_contraint?
          result << "changing type" if changing_type?
        end
      end

      private

      attr_reader :instruction

      def adding_not_null_contraint?
        instruction.alterations.key?(:null) &&
          !instruction.alterations[:null]
      end

      def adding_unique_contraint?
        instruction.alterations.fetch(:unique, false)
      end

      def changing_type?
        instruction.alterations.key?(:type)
      end
    end
  end
end
