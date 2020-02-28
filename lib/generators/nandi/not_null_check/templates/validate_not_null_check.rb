# frozen_string_literal: true

class <%= validate_not_null_check_name.camelize %> < Nandi::Migration
  def up
    validate_constraint <%= format_value(@table) %>, <%= format_value(name) %>
  end

  def down; end
end
