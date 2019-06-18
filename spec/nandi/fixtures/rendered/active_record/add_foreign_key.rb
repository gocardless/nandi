class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(750)
  set_statement_timeout(1500)

  
  def up
  
    add_foreign_key(
  :payments,
  :mandates,
  {
  valid: false,
  name: :payments_mandates_fk,
  column: :zalgo_comes
}
)

  
  end
  
end
