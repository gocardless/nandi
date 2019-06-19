# frozen_string_literal: true

require "ostruct"

module Nandi
  module Instructions
    class CreateTable
      attr_reader :table, :columns, :timestamps_args, :extra_args

      def initialize(table:, columns_block:, **kwargs)
        @table = table
        columns_reader = ColumnsReader.new
        columns_block.call(columns_reader)
        @columns = columns_reader.columns
        @extra_args = kwargs unless kwargs.empty?
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

        TYPES = %i[
          bigint
          binary
          boolean
          date
          datetime
          decimal
          float
          integer
          json
          string
          text
          time
          timestamp
          virtual
          bigserial bit bit_varying box
          cidr circle citext
          daterange
          hstore
          inet int4range int8range interval
          jsonb
          line lseg ltree
          macaddr money
          numrange
          oid
          path point polygon primary_key
          serial
          tsrange tstzrange tsvector
          uuid
          xml
        ].freeze

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

        TYPES.each do |type|
          define_method type do |name, **args|
            column(name, type, **args)
          end
        end
      end
    end
  end
end
