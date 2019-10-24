class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(5000)
  set_statement_timeout(1080000)

  
  def up
  
    execute <<-SQL
  ALTER TABLE payments VALIDATE CONSTRAINT payments_mandates_fk
SQL

  
  end
  
end
