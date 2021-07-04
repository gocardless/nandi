# frozen_string_literal: true

require "rails/generators"
require "nandi/formatting"

module Nandi
  class ReferenceGenerator < Rails::Generators::Base
    include Nandi::Formatting

    argument :table, type: :string
    argument :model, type: :string
    class_option :polymorphic, type: :boolean, default: false

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_reference_name

    def add_reference
      self.table = table.to_sym
      self.model = model.to_sym

      @add_reference_name = "add_reference_on_#{table}_to_#{model}"

      template(
        "add_reference.rb",
        "#{base_path}/#{timestamp}_#{add_reference_name}.rb",
      )
    end

    def add_index
      self.table = table.to_sym
      self.model = model.to_sym

      template(
        "add_index.rb",
        "#{base_path}/#{timestamp(1)}_#{add_index_name}.rb",
      )
    end

    private

    def index_columns
      if polymorphic?
        [:"#{model}_id", :"#{model}_type"]
      else
        :"#{model}_id"
      end
    end

    def add_index_name
      if polymorphic?
        "index_#{table}_on_#{model}_id_#{model}_type"
      else
        "index_#{table}_on_#{model}_id"
      end
    end

    def polymorphic?
      options["polymorphic"]
    end

    def base_path
      Nandi.config.migration_directory || "db/safe_migrations"
    end

    def timestamp(offset = 0)
      (Time.now.utc + offset).strftime("%Y%m%d%H%M%S")
    end
  end
end
