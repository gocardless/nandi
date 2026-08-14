# frozen_string_literal: true

require "nandi/renderers/active_record/generate"
require "nandi/yugabyte/renderers/active_record_yugabyte/instructions"

module Nandi
  module Renderers
    module ActiveRecordYugabyte
      class Generate < Nandi::Renderers::ActiveRecord::Generate
        def partials_base
          "nandi/renderers/active_record/instructions"
        end
      end
    end
  end
end
