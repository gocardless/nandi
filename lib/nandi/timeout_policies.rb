# frozen_string_literal: true

require "nandi/validation/failure_helpers"
require "nandi/migration"
require "nandi/timeout_policies/access_exclusive"
require "nandi/timeout_policies/concurrent"

module Nandi
  module TimeoutPolicies
    CONCURRENT_OPERATIONS = %i[add_index remove_index].freeze
    class Noop
      class << self
        include Nandi::Validation::FailureHelpers

        def validate(_)
          success
        end
      end
    end

    def self.policy_for(instruction)
      case instruction.lock
      when Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
        AccessExclusive
      else
        share_policy_for(instruction)
      end
    end

    def self.share_policy_for(instruction)
      if CONCURRENT_OPERATIONS.include?(instruction.procedure)
        Concurrent
      else
        Noop
      end
    end
  end
end
