# frozen_string_literal: true

require "nandi"
require "nandi/validation/failure_helpers"

module Nandi
  module TimeoutPolicies
    class Concurrent
      include Nandi::Validation::FailureHelpers

      def self.validate(migration)
        new(migration).validate
      end

      def initialize(migration)
        @migration = migration
      end

      def validate
        assert(
          migration.statement_timeout >= minimum_statement_timeout,
          "statement timeout for concurrent operations "\
          "must be at least #{minimum_statement_timeout}",
        )
      end

      private

      attr_accessor :migration

      def minimum_statement_timeout
        Nandi.config.concurrent_statement_timeout_limit
      end
    end
  end
end
