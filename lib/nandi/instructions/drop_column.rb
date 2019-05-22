# frozen_string_literal: true

module Nandi
  module Instructions
    class DropColumn
      attr_reader :table, :name, :extra_args

      def initialize(table:, name:, **extra_args)
        @table = table
        @name = name
        @extra_args = extra_args if extra_args.any?
      end

      def procedure
        :drop_column
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
