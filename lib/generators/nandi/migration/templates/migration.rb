# frozen_string_literal: true

class <%= class_name %> < Nandi::Migration
  def up
    # Migration instructions go here, eg:
    # add_index :payments, [:foo, :bar]
  end

  def down
    # Reverse migration instructions go here, eg:
    # remove_index :payments, :index_payments_on_foo_bar
  end
end

