# frozen_string_literal: true

module Nandi
  module Instructions
    class CreateTable
      def initialize(table:, columns_block:)
        @table = table
        columns_reader = ColumnsReader.new
        columns_block.call(columns_reader)
        @columns = columns_reader.columns
      end

      def procedure
        :create_table
      end

      def arguments
        [
          table,
          columns,
        ]
      end

      private

      attr_reader :table, :columns

      class ColumnsReader
        attr_reader :columns

        def initialize
          @columns = []
        end

        def column(name, type, **args)
          @columns << Array([name, type, args])
        end
      end
    end
  end
end
