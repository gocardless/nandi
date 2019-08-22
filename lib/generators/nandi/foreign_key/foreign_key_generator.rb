# frozen_string_literal: true

require "rails/generators"
require "nandi/formatting"

module Nandi
  class ForeignKeyGenerator < Rails::Generators::Base
    include Nandi::Formatting

    argument :table, type: :string
    argument :target, type: :string
    class_option :name, type: :string
    class_option :column, type: :string
    class_option :validation_timeout, type: :numeric, default: 15 * 60 * 1000

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_foreign_key_name, :validate_foreign_key_name

    def add_foreign_key
      self.table = table.to_sym
      self.target = target.to_sym

      @add_foreign_key_name = "add_foreign_key_on_#{table}_to_#{target}"

      template(
        "add_foreign_key.rb",
        "#{base_path}/#{timestamp}_#{add_foreign_key_name}.rb",
      )
    end

    def validate_foreign_key
      self.table = table.to_sym
      self.target = target.to_sym

      @validate_foreign_key_name = "validate_foreign_key_on_#{table}_to_#{target}"

      template(
        "validate_foreign_key.rb",
        "#{base_path}/#{timestamp(1)}_#{validate_foreign_key_name}.rb",
      )
    end

    private

    def base_path
      Nandi.config.migration_directory || "db/safe_migrations"
    end

    def timestamp(offset = 0)
      (Time.now.utc + offset).strftime("%Y%m%d%H%M%S")
    end

    def name
      options["name"]&.to_sym || :"#{@table}_#{@target}_fk"
    end

    def column
      options["column"]&.to_sym
    end

    def any_options?
      options["name"] || options["column"]
    end

    def validation_timeout
      options["validation_timeout"]
    end
  end
end
