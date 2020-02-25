# frozen_string_literal: true

require "nandi"
require "nandi/validation"
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
        collect_errors(
          validate_statement_timeout,
          validate_lock_timeout,
        )
      end

      private

      attr_accessor :migration

      def validate_statement_timeout
        assert(
          migration.disable_statement_timeout? || statement_timeout_high_enough,
          "statement timeout for concurrent operations "\
          "must be at least #{minimum_statement_timeout}",
        )
      end

      def validate_lock_timeout
        assert(
          migration.disable_lock_timeout? || lock_timeout_high_enough,
          "lock timeout for concurrent operations "\
          "must be at least #{minimum_lock_timeout}",
        )
      end

      def statement_timeout_high_enough
        migration.statement_timeout >= minimum_statement_timeout
      end

      def lock_timeout_high_enough
        migration.lock_timeout >= minimum_lock_timeout
      end

      def minimum_lock_timeout
        Nandi.config.concurrent_lock_timeout_limit
      end

      def minimum_statement_timeout
        Nandi.config.concurrent_statement_timeout_limit
      end
    end
  end
end
