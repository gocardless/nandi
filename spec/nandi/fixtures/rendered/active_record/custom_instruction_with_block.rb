class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(5000)
  set_statement_timeout(1500)

  
  def up
  
    new_method block rockin' beats
  
  end
  
end
