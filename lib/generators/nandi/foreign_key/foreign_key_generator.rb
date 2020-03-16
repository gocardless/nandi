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
    class_option :type, type: :string, default: "bigint"
    class_option :no_create_column, type: :boolean
    class_option :validation_timeout, type: :numeric, default: 15 * 60 * 1000

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_reference_name,
                :add_foreign_key_name,
                :validate_foreign_key_name

    def add_reference
      return if options["no_create_column"]

      self.table = table.to_sym

      @add_reference_name = "add_reference_on_#{table}_to_#{target}"

      template(
        "add_reference.rb",
        "#{base_path}/#{timestamp}_#{add_reference_name}.rb",
      )
    end

    def add_foreign_key
      self.table = table.to_sym
      self.target = target.to_sym

      @add_foreign_key_name = "add_foreign_key_on_#{table}_to_#{target}"

      template(
        "add_foreign_key.rb",
        "#{base_path}/#{timestamp(1)}_#{add_foreign_key_name}.rb",
      )
    end

    def validate_foreign_key
      self.table = table.to_sym
      self.target = target.to_sym

      @validate_foreign_key_name = "validate_foreign_key_on_#{table}_to_#{target}"

      template(
        "validate_foreign_key.rb",
        "#{base_path}/#{timestamp(2)}_#{validate_foreign_key_name}.rb",
      )
    end

    private

    def type
      options["type"].to_sym
    end

    def reference_name
      "#{target.singularize}_id".to_sym
    end

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
  end
end
