# frozen_string_literal: true

require "rails/generators"
require "nandi/formatting"
require "nandi/multi_db_generator"

module Nandi
  class IndexGenerator < Rails::Generators::Base
    include Nandi::Formatting
    include MultiDbGenerator

    argument :tables, type: :string
    argument :columns, type: :string
    class_option :index_name, type: :string

    source_root File.expand_path("templates", __dir__)

    attr_reader :add_index_name, :index_name, :table, :columns

    def add_index
      tables_list = tables.split(",")
      @columns = columns.split(",")

      tables_list.each_with_index do |table, idx|
        next if table.empty?

        @table = table.to_sym

        @add_index_name = "add_index_on_#{columns.join('_')}_to_#{table}"
        @index_name = (
          override_index_name || "idx_#{table}_on_#{columns.join('_')}"
        ).to_sym

        template(
          "add_index.rb",
          "#{base_path}/#{timestamp(idx)}_#{add_index_name}.rb",
        )
      end
    end

    private

    def timestamp(offset = 0)
      (Time.now.utc + offset).strftime("%Y%m%d%H%M%S")
    end

    def override_index_name
      options["index_name"]&.to_sym
    end
  end
end
