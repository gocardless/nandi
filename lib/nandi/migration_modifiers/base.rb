# frozen_string_literal: true

module Nandi
  module MigrationModifiers
    class Base
      def self.up(instructions); end
      def self.down(instructions); end
    end
  end
end
