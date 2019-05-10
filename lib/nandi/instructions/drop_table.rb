# frozen_string_literal: true

module Nandi
  module Instructions
    class DropTable
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def procedure
        :drop_table
      end
    end
  end
end
