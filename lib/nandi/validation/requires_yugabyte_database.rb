# frozen_string_literal: true

module Nandi
  module Validation
    module RequiresYugabyteDatabase
      def assert_yugabyte_database
        assert(
          Nandi.config.yugabyte_database?,
          "#{instruction.procedure}: this instruction can only be used when the target database is " \
          "configured as YugabyteDB (pass `yugabyte_database: true` to `register_database`).",
        )
      end
    end
  end
end
