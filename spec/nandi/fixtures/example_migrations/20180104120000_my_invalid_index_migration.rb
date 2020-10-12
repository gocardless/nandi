# frozen_string_literal: true

class MyInvalidIndexMigration < Nandi::Migration
  def up
    add_index :payments, :foo, using: :gin
  end

  def down
    remove_index :payments, :foo
  end
end
