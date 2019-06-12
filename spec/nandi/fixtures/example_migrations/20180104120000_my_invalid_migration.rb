# frozen_string_literal: true

class MyInvalidMigration < Nandi::Migration
  def up
    add_index :payments, :foo
    add_index :payments, :bar
  end

  def down
    remove_index :payments, :foo
    remove_index :payments, :bar
  end
end
