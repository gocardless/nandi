# frozen_string_literal: true

module Nandi
  module Instructions
    class DropConstraint
      attr_reader :table, :name

      def initialize(table:, name:)
        @table = table
        @name = name
      end

      def procedure
        :drop_constraint
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
