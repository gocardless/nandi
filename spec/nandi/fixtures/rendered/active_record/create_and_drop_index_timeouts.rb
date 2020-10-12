class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(5000)
  

  disable_ddl_transaction!
  def up
  
    add_index(
  :payments,
  [:foo, :bar],
  {
  name: :idx_payments_on_foo_bar,
  using: :btree,
  algorithm: :concurrently
}
)

  
  end
  
  def down
  
    remove_index(
  :payments,
  {
  column: [:foo, :bar],
  algorithm: :concurrently
}
)

  
  end
  
end
