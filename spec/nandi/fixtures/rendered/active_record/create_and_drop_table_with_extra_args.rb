class MyAwesomeMigration < ActiveRecord::Migration[8.0]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    create_table :payments, id: false, force: true do |t|
      t.column :payer, :string
      t.column :ammount, :float
      t.column :payed, :bool, default: false
end

  
  end
  
  def down
  
    drop_table :payments

  
  end
  
end
