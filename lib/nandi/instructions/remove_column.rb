# frozen_string_literal: true

module Nandi
  module Instructions
    class RemoveColumn
      attr_reader :table, :name, :extra_args

      def initialize(table:, name:, **extra_args)
        @table = table
        @name = name
        @extra_args =
          if extra_args.any?
            extra_args
          else
            {}
          end
      end

      def procedure
        :remove_column
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end
    end
  end
end
