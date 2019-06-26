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
        Result.new(@instruction).tap do |result|
          result << "non-null column lacks default" unless nullable? || default_value?
          result << "column is unique" if unique?
        end
      end

      attr_reader :instruction

      private

      def default_value?
        !instruction.extra_args[:default].nil?
      end

      def nullable?
        instruction.extra_args[:null]
      end

      def unique?
        instruction.extra_args.fetch(:unique, false)
      end
    end
  end
end
