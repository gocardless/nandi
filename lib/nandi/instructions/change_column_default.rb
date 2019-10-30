# frozen_string_literal: true

module Nandi
  module Instructions
    class ChangeColumnDefault
      attr_reader :table, :column, :value

      def initialize(table:, column:, value:)
        @table = table
        @column = column
        @value = value
      end

      def procedure
        :change_column_default
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
