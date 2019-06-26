# frozen_string_literal: true

class <%= validate_foreign_key_name.camelize %> < Nandi::Migration
  def up
    validate_constraint <%= format_value(@table) %>, <%= format_value(name) %>
  end

  def down; end
end

