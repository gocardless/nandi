# frozen_string_literal: true

module Nandi
  module Instructions
    module Yugabyte
      class AddIndexYb < Nandi::Instructions::AddIndex
        def procedure
          :add_index_yb
        end

        def template
          Nandi::Renderers::ActiveRecordYugabyte::Instructions::AddIndexYbCell
        end
      end
    end
  end
end
