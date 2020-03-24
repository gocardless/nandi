# frozen_string_literal: true

module Nandi
  module Instructions
    class AddIndex
      def initialize(fields:, table:, **kwargs)
        @fields = Array(fields)
        @fields = @fields.first if @fields.one?

        @table = table
        @extra_args = kwargs
      end

      def procedure
        :add_index
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

      def lock
        Nandi::Migration::LockWeights::SHARE
      end

      attr_reader :table, :fields

      private

      def name
        :"idx_#{table}_on_#{field_names}"
      end

      def field_names
        field_names = fields.respond_to?(:map) ? fields.map(&:to_s).join("_") : fields
        field_names.to_s.scan(/\w+/).join("_")
      end
    end
  end
end
