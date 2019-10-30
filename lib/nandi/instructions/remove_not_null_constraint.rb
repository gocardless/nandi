# frozen_string_literal: true

module Nandi
  module Instructions
    class RemoveNotNullConstraint
      attr_reader :table, :column

      def initialize(table:, column:)
        @table = table
        @column = column
      end

      def procedure
        :remove_not_null_constraint
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
