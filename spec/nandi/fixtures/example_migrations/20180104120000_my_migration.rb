# frozen_string_literal: true

class MyMigration < Nandi::Migration
  def up
    create_index :payments, :foo
  end

  def down
    drop_index :payments, :foo
  end
end
