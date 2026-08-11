# frozen_string_literal: true

module Nandi
  module Instructions
    module Yugabyte
      class AddIndexYb < Nandi::Instructions::AddIndex
        def procedure
          :add_index_yb
        end

        def template
          "nandi/renderers/active_record_yugabyte/instructions/add_index_yb"
        end
      end
    end
  end
end
