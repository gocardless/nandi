# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class InstructionValidator
      include Nandi::Validation::FailureHelpers

      def self.call(instruction, db_name = nil)
        new(instruction, db_name).call
      end

      def initialize(instruction, db_name)
        @instruction = instruction
        @db_name = db_name
      end

      def call
        raise NotImplementedError
      end

      def db_config
        @db_config ||= Nandi.config.database(@db_name)
      end

      attr_reader :instruction
    end
  end
end
