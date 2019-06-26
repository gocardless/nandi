# frozen_string_literal: true

module Nandi
  module Instructions
    class ValidateConstraint
      attr_reader :table, :name

      def initialize(table:, name:)
        @table = table
        @name = name
      end

      def procedure
        :validate_constraint
      end
    end
  end
end
