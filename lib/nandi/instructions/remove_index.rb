# frozen_string_literal: true

module Nandi
  module Instructions
    class RemoveIndex
      def initialize(table:, field:, concurrently: true)
        @table = table
        @field = field
        @concurrently = concurrently
      end

      def procedure
        :remove_index
      end

      def extra_args
        base = field.is_a?(Hash) ? field.dup : { column: columns }
        concurrently ? base.merge(algorithm: :concurrently) : base
      end

      def lock
        concurrently ? Nandi::Migration::LockWeights::SHARE : Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end

      def concurrent?
        concurrently
      end

      attr_reader :table

      private

      attr_reader :field, :concurrently

      def columns
        columns = Array(field)
        columns = columns.first if columns.one?

        columns
      end
    end
  end
end
