# frozen_string_literal: true

require "dry/monads"
require "nandi/migration"
require "nandi/timeout_policies/access_exclusive"

module Nandi
  module TimeoutPolicies
    class Noop
      class << self
        include Dry::Monads[:result]

        def validate(_)
          Success()
        end
      end
    end

    def self.policy_for(instruction)
      case instruction.lock
      when Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
        AccessExclusive
      else
        Noop
      end
    end
  end
end
