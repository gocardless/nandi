# frozen_string_literal: true

class <%= add_index_name.camelize %> < Nandi::Migration
  def up
    add_index <%= format_value(table) %>, <%= format_value(index_columns) %>
  end

  def down
    remove_index <%= format_value(table) %>, <%= format_value(index_columns) %>
  end
end
