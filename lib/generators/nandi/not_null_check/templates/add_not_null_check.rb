# frozen_string_literal: true

class <%= add_not_null_check_name.camelize %> < Nandi::Migration
  def up
    add_check_constraint <%= format_value(table) %>, <%= format_value(name) %>, "<%= column %> IS NOT NULL"
  end

  def down
    drop_constraint <%= format_value(table) %>, <%= format_value(name) %>
  end
end
