class MyAwesomeMigration < ActiveRecord::Migration[8.1]
  
  
  set_lock_timeout(5000)
  
  
  set_statement_timeout(1500)
  

  
  def up
  
    execute <<-SQL
  DO $$
  DECLARE
    actual_type text;
  BEGIN
    SELECT format_type(atttypid, atttypmod) INTO actual_type
    FROM pg_attribute
    WHERE attrelid = 'widgets'::regclass AND attname = 'name' AND NOT attisdropped;

    IF actual_type IS DISTINCT FROM 'character varying(2)' THEN
      RAISE EXCEPTION 'expected widgets.name to be character varying(2), found %', actual_type;
    END IF;
  END $$;

  ALTER TABLE widgets ALTER COLUMN "name" TYPE character varying;
SQL

  
  end
  
end
