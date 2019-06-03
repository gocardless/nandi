class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(750)
  set_statement_timeout(1500)

  
  def up
  
    execute <<-SQL
  ALTER TABLE payments
  ADD_CONSTRAINT payments_mandates_fk
  FOREIGN KEY (zalgo_comes)
  REFERENCES mandates (id)
  NOT VALID
SQL

  
  end
  
end
