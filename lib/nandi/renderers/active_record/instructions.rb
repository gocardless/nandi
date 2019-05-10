# frozen_string_literal: true

require "cells"
require "tilt"
require "nandi/formatting"

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
          def table
            model.arguments.first
          end

          def columns
            model.arguments.last
          end
        end

        class DropTableCell < Base
          def table
            model.arguments.first
          end
        end
      end
    end
  end
end
