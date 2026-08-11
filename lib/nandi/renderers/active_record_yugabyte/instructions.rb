# frozen_string_literal: true

require "nandi/renderers/active_record/instructions"

module Nandi
  module Renderers
    module ActiveRecordYugabyte
      module Instructions
        include Nandi::Renderers::ActiveRecord::Instructions

        class AddIndexYbCell < Nandi::Renderers::ActiveRecord::Instructions::Base
          # Because all this stuff goes into a SQL string, we don't need to format
          # the values.
          property :table
          property :fields
          property :extra_args

          def unique?
            model.extra_args[:unique]
          end

          def name
            model.extra_args[:name]
          end

          def fields
            if model.extra_args[:bucket_on].present?
              bucket_field = "(yb_hash_code(#{model.extra_args[:bucket_on]}) % #{model.extra_args[:bucket_count]})"
            end
            [bucket_field, *model.fields].compact.join(", ")
          end
        end
      end
    end
  end
end
