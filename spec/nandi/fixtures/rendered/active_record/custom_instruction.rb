class MyAwesomeMigration < ActiveRecord::Migration[8.0]
  
  
  disable_lock_timeout!
  
  
  disable_statement_timeout!
  

  
  def up
  
    new_method
  
  end
  
end
