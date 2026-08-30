class MyAwesomeMigration < ActiveRecord::Migration[8.0]


  set_lock_timeout(5000)


  set_statement_timeout(1500)



  def up

    execute <<-SQL
  ALTER TABLE payouts RENAME CONSTRAINT fx_sweep_id_credits_fk TO fx_sweep_id_payouts_fk
SQL



  end

end
