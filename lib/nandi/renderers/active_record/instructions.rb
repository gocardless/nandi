# frozen_string_literal: true

require "cells"
require "tilt"

module Nandi
  module Renderers
    module ActiveRecord
      module Instructions
        class Base < ::Cell::ViewModel
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
          property :arguments

          def table
            arguments.first
          end

          def kwargs
            arguments.last.inspect
          end
        end

        class CreateIndexCell < Base
          def table
            model.arguments.first
          end

          def columns
            model.arguments[1].inspect
          end

          def kwargs
            model.arguments.last.inspect
          end
        end
      end
    end
  end
end
