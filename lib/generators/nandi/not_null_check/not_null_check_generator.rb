# frozen_string_literal: true

require "rails/generators"
require "nandi/formatting"
require "nandi/multi_db_generator"

module Nandi
  class NotNullCheckGenerator < Rails::Generators::Base
    include Nandi::Formatting
    include Nandi::MultiDbGenerator

    argument :table, type: :string
    argument :column, type: :string
    class_option :validation_timeout, type: :numeric, default: 15 * 60 * 1000

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_not_null_check_name, :validate_not_null_check_name

    def add_not_null_check
      self.table = table.to_sym
      self.column = column.to_sym

      @add_not_null_check_name = "add_not_null_check_on_#{column}_to_#{table}"

      template(
        "add_not_null_check.rb",
        "#{base_path}/#{timestamp}_#{add_not_null_check_name}.rb",
      )
    end

    def validate_not_null_check
      self.table = table.to_sym
      self.column = column.to_sym

      @validate_not_null_check_name = "validate_not_null_check_on_#{column}_to_#{table}"

      template(
        "validate_not_null_check.rb",
        "#{base_path}/#{timestamp(1)}_#{validate_not_null_check_name}.rb",
      )
    end

    private

    def timestamp(offset = 0)
      (Time.now.utc + offset).strftime("%Y%m%d%H%M%S")
    end

    def name
      "#{table}_check_#{column}_not_null"
    end
  end
end
