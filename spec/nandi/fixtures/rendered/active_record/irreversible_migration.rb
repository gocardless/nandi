class MyAwesomeMigration < ActiveRecord::Migration[8.0]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    remove_column(
  :payments,
  :amount,
  **{
  
}
)

  
  end
  
  def down
  
    raise ActiveRecord::IrreversibleMigration
  
  end
  
end
