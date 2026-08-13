# frozen_string_literal: true

require "nandi/validation/instruction_validator"
require "nandi/validation/requires_yugabyte_database"

module Nandi
  module Validation
    class AddIndexYbValidator < InstructionValidator
      include Nandi::Validation::RequiresYugabyteDatabase

      def call
        assert_yugabyte_database
      end
    end
  end
end
