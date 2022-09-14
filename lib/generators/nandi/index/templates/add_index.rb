# frozen_string_literal: true

class <%= add_index_name.camelize %> < Nandi::Migration
  def up
    add_index <%= format_value(table) %>,
              %i<%= format_value(columns).tr('"', '') %>,
              name: <%= format_value(index_name) %>
  end

  def down
    remove_index <%= format_value(table) %>,
                 %i<%= format_value(columns).tr('"', '') %>
  end
end
