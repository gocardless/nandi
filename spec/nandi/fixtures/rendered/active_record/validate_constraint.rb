class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  
  disable_lock_timeout!
  
  
  disable_statement_timeout!
  

  
  def up
  
    execute <<-SQL
  ALTER TABLE payments VALIDATE CONSTRAINT payments_mandates_fk
SQL

  
  end
  
end
