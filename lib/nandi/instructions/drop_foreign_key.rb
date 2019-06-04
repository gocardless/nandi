# frozen_string_literal: true

module Nandi
  module Instructions
    class DropForeignKey
      attr_reader :table, :name

      def initialize(table:, name:)
        @table = table
        @name = name
      end

      def procedure
        :drop_foreign_key
      end
    end
  end
end
