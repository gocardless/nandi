# frozen_string_literal: true

class MyInvalidMigration < Nandi::Migration
  def up
    create_index :payments, :foo
    create_index :payments, :bar
  end

  def down
    drop_index :payments, :foo
    drop_index :payments, :bar
  end
end
