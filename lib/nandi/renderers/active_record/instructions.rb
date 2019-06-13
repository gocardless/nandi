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

        class RemoveIndexCell < Base
          formatted_property :table
          formatted_property :extra_args
        end

        class AddIndexCell < Base
          formatted_property :table
          formatted_property :fields
          formatted_property :extra_args
        end

        class CreateTableCell < Base
          formatted_property :table
          formatted_property :timestamps_args

          def timestamps?
            !model.timestamps_args.nil?
          end

          def timestamps_args?
            !model.timestamps_args&.empty?
          end

          def timestamps_args
            format_value(model.timestamps_args, as_argument: true)
          end

          def columns
            model.columns.map do |c|
              OpenStruct.new(
                name: format_value(c.name),
                type: format_value(c.type),
              ).tap do |col|
                col.args = format_value(c.args, as_argument: true) unless c.args.empty?
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

        class RemoveColumnCell < Base
          formatted_property :table
          formatted_property :name
          formatted_property :extra_args
        end

        class ChangeColumnCell < Base
          formatted_property :table
          formatted_property :name
          formatted_property :alterations
        end

        class AddForeignKeyCell < Base
          # Because all this stuff goes into a SQL string, we don't need to format
          # the values.
          property :table
          property :target
          property :column
          property :name
        end

        class ValidateForeignKeyCell < Base
          # Because all this stuff goes into a SQL string, we don't need to format
          # the values.
          property :table
          property :name
        end

        class DropForeignKeyCell < Base
          # Because all this stuff goes into a SQL string, we don't need to format
          # the values.
          property :table
          property :name
        end
      end
    end
  end
end
