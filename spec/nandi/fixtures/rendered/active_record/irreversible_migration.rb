class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(750)
  set_statement_timeout(1500)

  
  def up
  
    remove_column(
  :payments,
  :amount,
  nil
)

  
  end
  
  def down
  
    raise ActiveRecord::IrreversibleMigration
  
  end
  
end
