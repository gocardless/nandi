class MyAwesomeMigration < ActiveRecord::Migration[8.0]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    execute <<-SQL
  ALTER TABLE payments
  ADD CONSTRAINT check
  CHECK (foo IS NOT NULL)
  NOT VALID
SQL


  
  end
  
end
