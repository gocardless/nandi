# frozen_string_literal: true

class <%= validate_check_constraint_name.camelize %> < Nandi::Migration
  def up
    validate_constraint <%= format_value(table) %>, <%= format_value(name) %>
  end

  def down; end
end
