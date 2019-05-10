# frozen_string_literal: true

module Nandi
  module Instructions
    class DropTable
      def initialize(table:)
        @table = table
      end

      def procedure
        :drop_table
      end

      def arguments
        [
          table,
        ]
      end

      private

      attr_reader :table
    end
  end
end
