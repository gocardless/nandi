# frozen_string_literal: true

module Nandi
  module Instructions
    class AddReference
      DEFAULT_EXTRA_ARGS = { index: false }.freeze
      attr_reader :table, :ref_name, :extra_args

      def initialize(table:, ref_name:, **kwargs)
        @table = table
        @ref_name = ref_name
        @extra_args = DEFAULT_EXTRA_ARGS.merge(kwargs)
      end

      def procedure
        :add_reference
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
