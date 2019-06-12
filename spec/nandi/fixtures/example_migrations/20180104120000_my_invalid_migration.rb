# frozen_string_literal: true

class MyInvalidMigration < Nandi::Migration
  def up
    add_index :payments, :foo
    add_index :payments, :bar
  end

  def down
    drop_index :payments, :foo
    drop_index :payments, :bar
  end
end
