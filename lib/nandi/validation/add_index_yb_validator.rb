# frozen_string_literal: true

require "nandi/validation/failure_helpers"
require "nandi/validation/requires_yugabyte_database"

module Nandi
  module Validation
    class AddIndexYbValidator
      include Nandi::Validation::FailureHelpers
      include Nandi::Validation::RequiresYugabyteDatabase

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        assert_yugabyte_database
      end

      attr_reader :instruction
    end
  end
end
