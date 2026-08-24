# frozen_string_literal: true

require "nandi/postgres_database"
require "nandi/yugabyte/nandi/yugabyte_database"

module Nandi
  DATABASES = {
    postgres: PostgresDatabase,
    yugabyte: YugabyteDatabase,
  }.freeze
end
