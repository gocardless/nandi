# frozen_string_literal: true

require "nandi"
require "nandi/validation/failure_helpers"

module Nandi
  module TimeoutPolicies
    class AccessExclusive
      include Nandi::Validation::FailureHelpers

      def self.validate(migration)
        new(migration).validate
      end

      def initialize(migration)
        @migration = migration
      end

      def validate
        collect_errors(validate_statement_timeout, validate_lock_timeout)
      end

      private

      attr_reader :migration

      def validate_statement_timeout
        assert(
          !migration.disable_statement_timeout? &&
          migration.statement_timeout <= statement_timeout_maximum,
          "statement timeout must be at most #{statement_timeout_maximum}ms" \
          " as it takes an ACCESS EXCLUSIVE lock",
        )
      end

      def validate_lock_timeout
        assert(
          !migration.disable_lock_timeout? &&
          migration.lock_timeout <= lock_timeout_maximum,
          "lock timeout must be at most #{lock_timeout_maximum}ms" \
          " as it takes an ACCESS EXCLUSIVE lock",
        )
      end

      def statement_timeout_maximum
        Nandi.config.access_exclusive_statement_timeout_limit
      end

      def lock_timeout_maximum
        Nandi.config.access_exclusive_lock_timeout_limit
      end
    end
  end
end
