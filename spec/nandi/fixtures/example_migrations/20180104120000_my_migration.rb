# frozen_string_literal: true

class MyMigration < Nandi::Migration
  def up
    add_index :payments, :foo
  end

  def down
    remove_index :payments, :foo
  end
end
