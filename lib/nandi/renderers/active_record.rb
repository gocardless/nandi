# frozen_string_literal: true

require "nandi/renderers/active_record_yugabyte/generate"

module Nandi
  module Renderers
    module ActiveRecord
      def self.generate(migration)
        Nandi::Renderers::ActiveRecordYugabyte::Generate.call(migration)
      end
    end
  end
end
