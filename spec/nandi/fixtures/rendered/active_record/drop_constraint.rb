class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(750)
  set_statement_timeout(1500)

  
  def up
  
    execute <<-SQL
  ALTER TABLE payments DROP CONSTRAINT payments_mandates_fk
SQL


  
  end
  
end
