# frozen_string_literal: true

require "nandi/renderers/abstract_generate"
require "active_record"
require "nandi/renderers/active_record/instructions"

module Nandi
  module Renderers
    module ActiveRecord
      class Generate < Nandi::Renderers::AbstractGenerate
        def partials_base
          "nandi/renderers/active_record/instructions"
        end

        def activerecord_version
          ::ActiveRecord::Migration.current_version
        end
      end
    end
  end
end
