# frozen_string_literal: true

require "dry/monads/result"

module Nandi
  module Validation
    module FailureHelpers
      def collect_errors(new, old)
        return success if new.success? && old.success?

        if old.failure?
          failure(Array(old.failure) + Array(new.failure))
        else
          failure(Array(new.failure))
        end
      end

      def success
        Dry::Monads::Result::Success.new(nil)
      end

      def failure(value)
        Dry::Monads::Result::Failure.new(value)
      end

      def assert(condition, message)
        if condition
          success
        else
          failure(message)
        end
      end
    end
  end
end
