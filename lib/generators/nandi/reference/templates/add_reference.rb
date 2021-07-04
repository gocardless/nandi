# frozen_string_literal: true

class <%= add_reference_name.camelize %> < Nandi::Migration
  def up
    add_reference <%= format_value(table) %>, <%= format_value(model) %><% if polymorphic? %>, polymorphic: true<% end %>
  end

  def down
    remove_reference <%= format_value(table) %>, <%= format_value(model) %>
  end
end
