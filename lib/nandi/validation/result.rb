# frozen_string_literal: true

module Nandi
  module Validation
    class Result
      attr_reader :errors

      def initialize(instruction = nil)
        @instruction = instruction
        @errors = []
      end

      def valid?
        @errors.empty?
      end

      def <<(error)
        error = "#{@instruction.procedure}: #{error}" if @instruction
        @errors << error
        self
      end

      def error_list
        @errors.join("\n")
      end

      def merge(result)
        result.errors.each do |error|
          @errors << error
        end

        self
      end
    end
  end
end
