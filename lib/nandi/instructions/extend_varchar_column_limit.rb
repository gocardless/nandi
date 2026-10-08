# frozen_string_literal: true

module Nandi
  module Instructions
    class ExtendVarcharColumnLimit
      attr_reader :table, :column, :from, :to

      def initialize(table:, column:, from:, to:)
        unless from.is_a?(Integer)
          raise ArgumentError, "extend_varchar_column_limit requires an integer `from:` limit"
        end

        unless to.nil? || (to.is_a?(Integer) && to > from)
          raise ArgumentError,
                "extend_varchar_column_limit only supports widening a character limit, or " \
                "removing it entirely (to: nil), but #{table}.#{column} would go from #{from} " \
                "to #{to.inspect}. Narrowing a limit requires a full-table scan under an " \
                "ACCESS EXCLUSIVE lock and isn't supported here."
        end

        @table = table
        @column = column
        @from = from
        @to = to
      end

      def procedure
        :extend_varchar_column_limit
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
