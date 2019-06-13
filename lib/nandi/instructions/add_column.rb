# frozen_string_literal: true

module Nandi
  module Instructions
    class AddColumn
      attr_reader :table, :name, :type, :extra_args

      def initialize(table:, name:, type:, **kwargs)
        @table = table
        @name = name
        @type = type
        @extra_args = kwargs
      end

      def procedure
        :add_column
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
