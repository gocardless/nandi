# frozen_string_literal: true

module Nandi
  module Instructions
    class RenameConstraint
      attr_reader :table, :old_name, :new_name

      def initialize(table:, old_name:, new_name:)
        @table = table
        @old_name = old_name
        @new_name = new_name
      end

      def procedure
        :rename_constraint
      end

      def lock
        # RENAME CONSTRAINT requires ACCESS EXCLUSIVE lock, but it's a fast
        # metadata-only operation that completes in milliseconds
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
