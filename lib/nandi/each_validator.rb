# frozen_string_literal: true

module Nandi
  class DropIndexValidator
    def self.call(instruction)
      new(instruction).call
    end

    def initialize(instruction)
      @instruction = instruction
    end

    def call
      _, opts = instruction.arguments

      opts.key?(:name) || opts.key?(:column)
    end

    attr_reader :instruction
  end

  class EachValidator
    def self.call(instruction)
      new(instruction).call
    end

    def initialize(instruction)
      @instruction = instruction
    end

    def call
      case instruction.procedure
      when :drop_index
        DropIndexValidator.call(instruction)
      else
        true
      end
    end

    attr_reader :instruction
  end
end
