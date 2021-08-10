class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    add_reference(
  :payments,
  :mandate,
  **{
  index: false,
  type: :text
}
)

  
  end
  
  def down
  
    remove_reference(
  :payments,
  :mandate,
  **{
  
}
)

  
  end
  
end
