# frozen_string_literal: true

require "rails/generators"
require "nandi/formatting"
require "nandi/multi_db_generator"

module Nandi
  class CheckConstraintGenerator < Rails::Generators::Base
    include Nandi::Formatting
    include MultiDbGenerator

    argument :table, type: :string
    argument :name, type: :string
    class_option :validation_timeout, type: :numeric, default: 15 * 60 * 1000

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_check_constraint_name, :validate_check_constraint_name

    def add_check_constraint
      self.table = table.to_sym
      self.name = name.to_sym

      @add_check_constraint_name = "add_check_constraint_#{name}_on_#{table}"

      template(
        "add_check_constraint.rb",
        "#{base_path}/#{timestamp}_#{add_check_constraint_name}.rb",
      )
    end

    def validate_check_constraint
      self.table = table.to_sym
      self.name = name.to_sym

      @validate_check_constraint_name = "validate_check_constraint_#{name}_on_#{table}"

      template(
        "validate_check_constraint.rb",
        "#{base_path}/#{timestamp(1)}_#{validate_check_constraint_name}.rb",
      )
    end

    private

    def timestamp(offset = 0)
      (Time.now.utc + offset).strftime("%Y%m%d%H%M%S")
    end
  end
end
