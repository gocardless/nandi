# frozen_string_literal: true

require "nandi/instructions"
require "nandi/validator"

module Nandi
  class Migration
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
