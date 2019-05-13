# frozen_string_literal: true

require "ostruct"

module Nandi
  module Instructions
    class CreateTable
      attr_reader :table, :columns

      def initialize(table:, columns_block:)
        @table = table
        columns_reader = ColumnsReader.new
        columns_block.call(columns_reader)
        @columns = columns_reader.columns
      end

      def procedure
        :create_table
      end

      class ColumnsReader
        attr_reader :columns

        def initialize
          @columns = []
        end

        def column(name, type, **args)
          @columns << OpenStruct.new(name: name, type: type, args: args)
        end
      end
    end
  end
end
