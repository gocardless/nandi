# frozen_string_literal: true

class MyMigration < Nandi::Migration
  def up
    create_table :payments, do |t|
      t.column :payer, :string
      t.column :ammount, :float
      t.column :payed, :bool, default: false
    end
  end

  def down
    drop_table :payments
  end
end
