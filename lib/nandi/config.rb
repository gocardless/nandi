# frozen_string_literal: true

require "nandi/renderers"

module Nandi
  class Config
    DEFAULT_LOCK_TIMEOUT = 750
    DEFAULT_STATEMENT_TIMEOUT = 1500

    attr_accessor :renderer, :lock_timeout, :statement_timeout
    attr_reader :post_processor

    def initialize(renderer: Renderers::ActiveRecord)
      @renderer = renderer
      @lock_timeout = DEFAULT_LOCK_TIMEOUT
      @statement_timeout = DEFAULT_STATEMENT_TIMEOUT
    end

    def post_process(&block)
      @post_processor = block
    end
  end
end
