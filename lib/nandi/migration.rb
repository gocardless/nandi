# frozen_string_literal: true

require "nandi/instructions"
require "nandi/validator"

module Nandi
  class Migration
    class << self
      def lock_timeout
        @lock_timeout ||= Nandi.config.lock_timeout
      end

      def statement_timeout
        @statement_timeout ||= Nandi.config.statement_timeout
      end

      # For sake both of correspondence with Postgres syntax and familiarity
      # with ActiveRecord's identically named macros, we disable this cop.
      # rubocop:disable Naming/AccessorMethodName
      def set_lock_timeout(timeout)
        @lock_timeout = timeout
      end

      def set_statement_timeout(timeout)
        @statement_timeout = timeout
      end
      # rubocop:enable Naming/AccessorMethodName
    end

    def initialize(validator)
      @validator = validator
      @instructions = Hash.new { |h, k| h[k] = [] }
    end

    def up_instructions
      compile_instructions(:up)
    end

    def down_instructions
      compile_instructions(:down)
    end

    def lock_timeout
      self.class.lock_timeout
    end

    def statement_timeout
      self.class.statement_timeout
    end

    def up
      raise NotImplementedError
    end

    def down; end

    def create_index(table, fields, **kwargs)
      current_instructions << Instructions::CreateIndex.new(
        **kwargs,
        table: table,
        fields: fields,
      )
    end

    def drop_index(table, field)
      current_instructions << Instructions::DropIndex.new(table: table, field: field)
    end

    def create_table(table, &block)
      current_instructions << Instructions::CreateTable.new(
        table: table,
        columns_block: block,
      )
    end

    def drop_table(table)
      current_instructions << Instructions::DropTable.new(table: table)
    end

    def compile_instructions(direction)
      @direction = direction

      public_send(direction) unless current_instructions.any?

      current_instructions
    end

    def valid?
      validator.call(up_instructions) && validator.call(down_instructions)
    rescue NotImplementedError
      false
    end

    def name
      self.class.name
    end

    private

    attr_reader :validator

    def current_instructions
      @instructions[@direction]
    end

    def current_instructions=(value)
      @instructions[@direction] = value
    end
  end
end
