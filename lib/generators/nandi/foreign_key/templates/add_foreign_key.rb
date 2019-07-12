# frozen_string_literal: true

class <%= add_foreign_key_name.camelize %> < Nandi::Migration
  def up
    add_foreign_key <%= format_value(table) %>, <%= format_value(target) %><% if any_options? %>,
        <% if column %>column: <%= format_value(column) %><% end %><% if column && name %>,<% end %>
        <% if name %>name: <%= format_value(name) %><% end %> <% end %>
  end

  def down
    drop_constraint <%= format_value(table) %>, <%= format_value(name) %>
  end
end
