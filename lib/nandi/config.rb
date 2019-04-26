# frozen_string_literal: true

require "nandi/renderers"

module Nandi
  class Config
    attr_accessor :renderer
    attr_reader :post_processor

    def initialize(renderer: Renderers::ActiveRecord)
      @renderer = renderer
    end

    def post_process(&block)
      @post_processor = block
    end
  end
end
