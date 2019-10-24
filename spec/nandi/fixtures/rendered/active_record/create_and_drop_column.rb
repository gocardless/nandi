class MyAwesomeMigration < ActiveRecord::Migration[5.2]
  
  set_lock_timeout(5000)
  set_statement_timeout(1500)

  
  def up
  
    add_column(
  :payments,
  :foo,
  :text,
  {
  collate: :de_DE
}
)

  
  end
  
  def down
  
    remove_column(
  :payments,
  :foo,
  {
  cascade: true
}
)

  
  end
  
end
