# frozen_string_literal: true

module Nandi
  module Instructions
    class RemoveIndex
      def initialize(table:, field:)
        @table = table
        @field = field
      end

      def procedure
        :remove_index
      end

      def extra_args
        if field.is_a?(Hash)
          field.merge(algorithm: :concurrently)
        else
          { column: columns, algorithm: :concurrently }
        end
      end

      def lock
        Nandi::Migration::LockWeights::SHARE
      end

      attr_reader :table

      private

      attr_reader :field

      def columns
        columns = Array(field)
        columns = columns.first if columns.one?

        columns
      end
    end
  end
end
