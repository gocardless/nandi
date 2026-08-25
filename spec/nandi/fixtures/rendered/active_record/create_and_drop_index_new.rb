class MyAwesomeMigration < ActiveRecord::Migration[8.0]
  
  
  disable_lock_timeout!
  
  
  disable_statement_timeout!
  

  disable_ddl_transaction!
  def up
  
    execute <<-SQL
  CREATE INDEX idx_payments_on_foo_bar ON payments ((yb_hash_code(id) % 16), foo, bar)
SQL

  
  end
  
  def down
  
    remove_index(
  :payments,
  **{
  column: [:foo, :bar],
  algorithm: :concurrently
}
)

  
  end
  
end
