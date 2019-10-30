# frozen_string_literal: true

require "nandi/validation/failure_helpers"

module Nandi
  module Validation
    class TimeoutValidator
      include Nandi::Validation::FailureHelpers

      def self.call(migration)
        new(migration).call
      end

      def initialize(migration)
        @migration = migration
      end

      def call
        timeout_policies.inject(success) do |result, policy|
          collect_errors(policy.validate(migration), result)
        end
      end

      private

      def timeout_policies
        instructions.map(&Nandi::TimeoutPolicies.method(:policy_for)).uniq
      end

      def instructions
        [*migration.up_instructions, *migration.down_instructions]
      end

      attr_reader :migration
    end
  end
end
