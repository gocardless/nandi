# frozen_string_literal: true

require "nandi/validation/failure_helpers"
module Nandi
  module Validation
    class Result
      include Nandi::Validation::FailureHelpers

      attr_reader :errors

      def initialize(instruction = nil)
        @instruction = instruction
        @errors = success
      end

      def valid?
        @errors.success?
      end

      def <<(error)
        @errors = collect_errors(error, @errors)
        self
      end

      def error_list
        @errors.failure.join("\n")
      end
    end
  end
end
