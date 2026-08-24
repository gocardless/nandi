# frozen_string_literal: true

module Nandi
  module Renderers
    class Renderer
      def self.for_database(database_type)
        database = Nandi::DATABASES.fetch(database_type) do
          raise "Unsupported database type #{database_type}"
        end
        database::RENDERER
      end

      def initialize(generator:)
        @generator = generator
      end

      def generate(migration)
        @generator.call(migration)
      end
    end
  end
end
