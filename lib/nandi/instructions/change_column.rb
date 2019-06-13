# frozen_string_literal: true

module Nandi
  module Instructions
    class ChangeColumn
      attr_reader :table, :name, :alterations

      def initialize(table:, name:, **alterations)
        @table = table
        @name = name
        @alterations = alterations
      end

      def procedure
        :change_column
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
