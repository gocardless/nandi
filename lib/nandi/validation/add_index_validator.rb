# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class AddIndexValidator
      include Nandi::Validation::FailureHelpers

      VALID_INDEX_TYPES = %i[btree hash].freeze

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        opts = instruction.extra_args

        return unless opts.key?(:using)

        assert(
          VALID_INDEX_TYPES.include?(opts.fetch(:using)),
          "add_index: index type can only be one of #{VALID_INDEX_TYPES}",
        )
      end

      attr_reader :instruction
    end
  end
end
