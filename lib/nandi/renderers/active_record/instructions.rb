# frozen_string_literal: true

require "cells"
require "tilt"
require "nandi/formatting"
require "ostruct"

module Nandi
  module Renderers
    module ActiveRecord
      module Instructions
        class Base < ::Cell::ViewModel
          include Nandi::Formatting

          def template_options_for(_options)
            {
              suffix: "rb.erb",
              template_class: Tilt,
            }
          end

          self.view_paths = [
            File.join(__dir__, "../../../templates"),
          ]
        end

        class DropIndexCell < Base
          formatted_property :table
          formatted_property :extra_args
        end

        class CreateIndexCell < Base
          formatted_property :table
          formatted_property :fields
          formatted_property :extra_args
        end

        class CreateTableCell < Base
          formatted_property :table

          def columns
            model.columns.map do |c|
              OpenStruct.new(
                name: format_value(c.name),
                type: format_value(c.type),
              ).tap do |col|
                col.args = format_value(c.args) unless c.args.empty?
              end
            end
          end
        end

        class DropTableCell < Base
          formatted_property :table
        end

        class AddColumnCell < Base
          formatted_property :table
          formatted_property :name
          formatted_property :type
          formatted_property :extra_args
        end

        class DropColumnCell < Base
          formatted_property :table
          formatted_property :name
          formatted_property :extra_args
        end
      end
    end
  end
end
