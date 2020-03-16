# frozen_string_literal: true

class <%= add_reference_name.camelize %> < Nandi::Migration
  def up
    add_column <%= format_value(table) %>, <%= format_value(reference_name) %>, <%= format_value(type) %>
  end

  def down
    remove_column <%= format_value(table) %>, <%= format_value(reference_name) %>
  end
end
