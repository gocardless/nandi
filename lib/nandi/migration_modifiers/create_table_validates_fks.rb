# frozen_string_literal: true

module Nandi
  module MigrationModifiers
    class CreateTableValidatesFks < Base
      def self.up(instructions)
        new_tables = instructions.
          select { |i| i.procedure == :create_table }.
          to_set { |i| i.table.to_sym }

        return if new_tables.empty?

        instructions.
          grep(Instructions::AddForeignKey).
          select { |i| new_tables.include?(i.table.to_sym) }.
          each(&:validate!)
      end
    end
  end
end
