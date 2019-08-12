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
    end
  end
end
