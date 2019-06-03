# frozen_string_literal: true

require "active_support/inflector"

module Nandi
  module Instructions
    class AddForeignKey
      attr_reader :table, :target

      def initialize(table:, target:, column: nil, name: nil)
        @table = table
        @target = target
        @column = column
        @name = name
      end

      def procedure
        :add_foreign_key
      end

      def name
        @name || :"#{table}_#{target}_fk"
      end

      def column
        @column || :"#{ActiveSupport::Inflector.singularize(target)}_id"
      end
    end
  end
end
