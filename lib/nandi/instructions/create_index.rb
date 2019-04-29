# frozen_string_literal: true

module Nandi
  module Instructions
    class CreateIndex
      def initialize(fields:, table:, **kwargs)
        @fields = Array(fields)
        @table = table
        @extra_args = kwargs
      end

      def procedure
        :create_index
      end

      def extra_args
        {
          # Overridable defaults
          name: name,

          # Overrides and extra options
          **@extra_args,

          # Mandatory values
          algorithm: :concurrently,
          using: :btree,
        }
      end

      attr_reader :table, :fields

      private

      def name
        :"idx_#{table.to_s}_on_#{fields.map(&:to_s).join("_")}"
      end
    end
  end
end
