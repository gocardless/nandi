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

      def extra_args
        if field.is_a?(Hash)
          field.merge(algorithm: :concurrently)
        else
          { column: Array(field), algorithm: :concurrently }
        end
      end

      def lock
        Nandi::Migration::LockWeights::SHARE
      end

      attr_reader :table

      private

      attr_reader :field
    end
  end
end
