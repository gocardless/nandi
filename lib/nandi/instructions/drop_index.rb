# frozen_string_literal: true

module Nandi
  module Instructions
    class DropIndex
      def initialize(table:, field:)
        @table = table
        @field = field
      end

      def procedure
        :drop_index
      end

      def arguments
        if field.is_a?(Hash)
          [table, field.merge(algorithm: :concurrently)]
        else
          [
            table,
            { column: Array(field), algorithm: :concurrently },
          ]
        end
      end

      attr_reader :table

      private

      attr_reader :field
    end
  end
end
