# frozen_string_literal: true

module Nandi
  module Instructions
    class AddCheckConstraint
      attr_reader :table, :name, :check

      def initialize(table:, name:, check:)
        @table = table
        @name = name
        @check = check
      end

      def procedure
        :add_check_constraint
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
