# frozen_string_literal: true

class <%= class_name %> < <%= superclass_name %>
  def up
    # Migration instructions go here, eg:
    # add_column :widgets, :size, :integer
  end

  def down
    # Reverse migration instructions go here, eg:
    # remove_column :widgets, :size
  end
end
