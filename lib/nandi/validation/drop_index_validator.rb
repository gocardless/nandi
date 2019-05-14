# frozen_string_literal: true

module Nandi
  module Validation
    class DropIndexValidator
      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        opts = instruction.extra_args

        Result.new(@instruction).tap do |result|
          unless opts.key?(:name) || opts.key?(:column)
            result << "requires a `name` or `column` argument"
          end
        end
      end

      attr_reader :instruction
    end
  end
end
