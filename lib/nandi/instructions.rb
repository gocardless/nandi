# frozen_string_literal: true

require "nandi/instructions/add_index"
require "nandi/instructions/remove_index"
require "nandi/instructions/create_table"
require "nandi/instructions/drop_table"
require "nandi/instructions/add_column"
require "nandi/instructions/remove_column"
require "nandi/instructions/change_column"
require "nandi/instructions/add_foreign_key"
require "nandi/instructions/drop_constraint"
require "nandi/instructions/remove_not_null_constraint"
require "nandi/instructions/validate_constraint"
require "nandi/instructions/add_check_constraint"

module Nandi
  module Instructions; end
end
