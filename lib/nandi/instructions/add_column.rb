# frozen_string_literal: true

module Nandi
  module Instructions
    class AddColumn
      attr_reader :table, :name, :type

      def initialize(table:, name:, type:, **kwargs)
        @table = table
        @name = name
        @type = type
        @extra_args = kwargs
      end

      def procedure
        :add_column
      end

      def extra_args
        { null: true, **@extra_args }
      end
    end
  end
end
