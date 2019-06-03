# frozen_string_literal: true

module Nandi
  module Instructions
    class ValidateForeignKey
      attr_reader :table, :name

      def initialize(table:, name:)
        @table = table
        @name = name
      end

      def procedure
        :validate_foreign_key
      end
    end
  end
end
