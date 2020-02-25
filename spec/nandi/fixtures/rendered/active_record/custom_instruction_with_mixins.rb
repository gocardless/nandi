class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  include My::Important::Mixin
include My::Other::Mixin
  
  disable_lock_timeout!
  
  
  disable_statement_timeout!
  

  
  def up
  
    new_method
  
  end
  
end
