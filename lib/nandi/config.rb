# frozen_string_literal: true

require "nandi/renderers"

module Nandi
  class Config
    DEFAULT_LOCK_TIMEOUT = 750
    DEFAULT_STATEMENT_TIMEOUT = 1500
    DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT = DEFAULT_STATEMENT_TIMEOUT
    DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT = DEFAULT_LOCK_TIMEOUT

    attr_accessor :renderer,
                  :lock_timeout,
                  :statement_timeout,
                  :access_exclusive_statement_timeout_limit,
                  :access_exclusive_lock_timeout_limit
    attr_reader :post_processor
    attr_reader :post_processor, :custom_methods

    def initialize(renderer: Renderers::ActiveRecord)
      @renderer = renderer
      @lock_timeout = DEFAULT_LOCK_TIMEOUT
      @statement_timeout = DEFAULT_STATEMENT_TIMEOUT
      @custom_methods = {}
      @access_exclusive_statement_timeout_limit =
        DEFAULT_ACCESS_EXCLUSIVE_STATEMENT_TIMEOUT_LIMIT
      @access_exclusive_lock_timeout_limit = DEFAULT_ACCESS_EXCLUSIVE_LOCK_TIMEOUT_LIMIT
    end

    def post_process(&block)
      @post_processor = block
    end

    def register_method(name, klass)
      custom_methods[name] = klass
    end
  end
end
