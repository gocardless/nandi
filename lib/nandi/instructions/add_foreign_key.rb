# frozen_string_literal: true

require "active_support/inflector"

module Nandi
  module Instructions
    class AddForeignKey
      attr_reader :table, :target

      def initialize(table:, target:, name: nil, **extra_args)
        @table = table
        @target = target
        @extra_args = extra_args
        @name = name
      end

      def procedure
        :add_foreign_key
      end

      def extra_args
        {
          **@extra_args,
          name: name,
          validate: false,
        }.compact
      end

      private

      def name
        @name || :"#{table}_#{target}_fk"
      end
    end
  end
end
