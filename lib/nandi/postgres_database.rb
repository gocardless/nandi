# frozen_string_literal: true

require "nandi/renderers/renderer"
require "nandi/renderers/active_record/generate"

module Nandi
  module PostgresDatabase
    RENDERER = Renderers::Renderer.new(generator: Nandi::Renderers::ActiveRecord::Generate)

    def self.superclass_name
      if Nandi.config.suppress_postgres_classname
        "Nandi::Migration"
      else
        "Nandi::Migration::Postgres"
      end
    end
  end
end
