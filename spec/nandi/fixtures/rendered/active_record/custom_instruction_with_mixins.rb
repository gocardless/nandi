class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  include My::Important::Mixin
include My::Other::Mixin
  set_lock_timeout(750)
  set_statement_timeout(1500)

  
  def up
  
    new_method
  
  end
  
end