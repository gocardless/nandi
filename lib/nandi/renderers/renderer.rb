# frozen_string_literal: true

require "nandi/renderers/active_record/generate"
require "nandi/renderers/active_record_yugabyte/generate"

module Nandi
  module Renderers
    class Renderer
      def self.for_database(database_type)
        case database_type
        when :postgres
          POSTGRES
        when :yugabyte
          YUGABYTE
        else
          raise "Unsupported database type #{database_type}"
        end
      end

      def initialize(generator:)
        @generator = generator
      end

      def generate(migration)
        @generator.call(migration)
      end

      POSTGRES = new(generator: Nandi::Renderers::ActiveRecord::Generate)
      YUGABYTE = new(generator: Nandi::Renderers::ActiveRecordYugabyte::Generate)
    end
  end
end
