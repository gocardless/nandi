# frozen_string_literal: true

require "ostruct"

module Nandi
  module Instructions
    class CreateTable
      attr_reader :table, :columns, :timestamps_args

      def initialize(table:, columns_block:)
        @table = table
        columns_reader = ColumnsReader.new
        columns_block.call(columns_reader)
        @columns = columns_reader.columns
        @timestamps_args = columns_reader.timestamps_args
      end

      def procedure
        :create_table
      end

      def lock
        Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
      end

      class ColumnsReader
        attr_reader :columns, :timestamps_args

        def initialize
          @columns = []
          @timestamps_args = nil
        end

        def column(name, type, **args)
          @columns << OpenStruct.new(name: name, type: type, args: args)
        end

        def timestamps(**args)
          @timestamps_args = args
        end
      end
    end
  end
end
