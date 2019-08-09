# frozen_string_literal: true

class <%= add_check_constraint_name.camelize %> < Nandi::Migration
  def up
    add_check_constraint <%= format_value(table) %>,
                         <%= format_value(name) %>,
                         <<~SQL
                           -- foo IS NOT NULL OR bar IS NOT NULL
                         SQL
  end

  def down
    drop_constraint <%= format_value(table) %>, <%= format_value(name) %>
  end
end
