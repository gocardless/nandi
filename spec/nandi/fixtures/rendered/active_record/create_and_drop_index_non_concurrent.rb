class MyAwesomeMigration < ActiveRecord::Migration[8.1]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    add_column(
  :payments,
  :foo,
  :text,
  **{
  
}
)

  
  end
  
  def down
  
    remove_index(
  :payments,
  **{
  column: :foo
}
)

  
  end
  
end
