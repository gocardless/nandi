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
    end
  end
end
