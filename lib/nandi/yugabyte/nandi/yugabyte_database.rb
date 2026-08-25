# frozen_string_literal: true

require "nandi/renderers/renderer"
require "nandi/yugabyte/nandi/renderers/active_record_yugabyte/generate"

module Nandi
  module YugabyteDatabase
    SUPERCLASS_NAME = "Nandi::Migration::Yugabyte"
    RENDERER = Renderers::Renderer.new(generator: Nandi::Renderers::ActiveRecordYugabyte::Generate)

    def self.superclass_name
      SUPERCLASS_NAME
    end
  end
end
