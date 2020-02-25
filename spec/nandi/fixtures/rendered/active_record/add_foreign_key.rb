class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    add_foreign_key(
  :payments,
  :mandates,
  {
  column: :zalgo_comes,
  name: :payments_mandates_fk,
  validate: false
}
)

  
  end
  
end
