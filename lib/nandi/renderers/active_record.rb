# frozen_string_literal: true

require "nandi/renderers/active_record/generate"

module Nandi
  module Renderers
    module ActiveRecord
      def self.generate(migration)
        Generate.call(migration)
      end
    end
  end
end
