class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
  
    add_index :payments, [:foo, :bar],
      {:name=>:idx_payments_on_foo_bar, :algorithm=>:concurrently, :using=>:btree}

  
  end
  
  def down
  
    remove_index :payments,
      {:column=>[:foo, :bar], :algorithm=>:concurrently}

  
  end
  
end
