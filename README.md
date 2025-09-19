# Nandi

Friendly Postgres migrations for people who don't want to take down their database to add a column!

## Supported

- Ruby 3.2 or above
- Rails 7.1 or above
- Postgres 11 or above

## What does it do?

Nandi provides an alternative API to ActiveRecord's built-in Migration DSL for defining changes to your database schema.

ActiveRecord makes many changes easy. Unfortunately, that includes things that should be done with great care. Consider this migration, for example:

```rb
class AddBarIDToFoos < ActiveRecord::Migration[8.0]
  def change
    add_reference :foos, :bars, foreign_key: true
  end
end
```

This is a perfectly ordinary thing to want to do - add a reference from one table to another and add a foreign key constraint, so that `bar_id` will always contain a value that appears in `bars`. But this actually takes very strict locks on both tables, `foos` and `bars`, while it checks that the constraint is valid. Depending on how large a table `bars` is, that could take a while; and if it does, your app will basically grind to a halt if it needs to access these tables. There are many such pitfalls around; and they generally only become dangerous when your database hits a certain size. There is hopefully a grizzled veteran engineer on your team who has memorised all the danger through bitter experience of 3am pages and 10 page post-mortems. But shouldn't we be able to do this with sofware, instead of scar tissue?

Enter Nandi!

![nandi](https://user-images.githubusercontent.com/2285130/56881872-bef6f500-6a59-11e9-8936-04d3861b6dce.gif)

Nandi offers availability-safe implementations of most common schema changes. It produces plain old ActiveRecord migration files, so existing Rails tooling can be leveraged for everything apart from correctness.

## Getting started

Add to your Gemfile:

```rb
gem 'nandi'
gem 'activerecord-safer_migrations' # Also required
```

Generate a new migration:

```sh
rails generate nandi:migration add_widgets
```

You'll get a fresh file, by default in `db/safe_migrations`. Let's use it to create a table with two fields, a name and a price, and the standard timestamps:

```rb
# db/safe_migrations/20190606060606_add_widgets.rb

class AddWidgets < Nandi::Migration
  def up
    create_table :widgets do |t|
      t.text :name
      t.integer :price

      t.timestamps
    end
  end

  def down
    drop_table :widgets
  end
end
```

Looks good! So let's generate an actual runnable ActiveRecord migration file.

```sh
rails generate nandi:compile
```

The result will sort of look like this:

```rb
# db/migrate/20190606060606_add_widgets.rb

class AddWidgets < ActiveRecord::Migration[8.0]
  set_lock_timeout(750)
  set_statement_timeout(1500)

  def up
    create_table :widgets do |t|
      t.column :name, :text
      t.column :price, :integer
      t.timestamps
    end
  end

  def down
    drop_table :widgets
  end
end
```

(But not quite - the indentation is likely to be skewiff and some syntax will be oddly formatted. We have focused on making sure that the output is correct, rather than readable, although the dream is to one day have the same files that you would write yourself if you knew exactly what you were doing.)

Now we can run the migration as we normally would.

```sh
rails db:migrate
```

And we're done!

Now in this case, Nandi hasn't done much for us. It's explicitly set reasonable timeouts, so slow operations won't block other work indefinitely, and that's that. Let's try another.

```rb
# db/safe_migrations/20190606060606_add_widgets_index_on_name_and_price.rb

class AddWidgetsIndexOnNameAndPrice < Nandi::Migration
  def up
    add_index :widgets, [:name, :price]
  end

  def down
    remove_index :widgets, [:name, :price]
  end
end

# db/migrate/20190606060606_add_widgets_index_on_name_and_price.rb

class AddWidgetsIndexOnNameAndPrice < ActiveRecord::Migration[8.0]
  set_lock_timeout(750)
  set_statement_timeout(1500)

  disable_ddl_transaction!
  def up
    add_index(
      :widgets,
      %i[name price],
      name: :idx_widgets_on_name_price,
      algorithm: :concurrently,
      using: :btree,
    )
  end

  def down
    remove_index(
      :widgets,
      column: %i[name price],
      algorithm: :concurrently,
    )
  end
end
```

Nandi has added in the `algorithm: :concurrently` option, ensuring that the index is not built immediately with the table locked in the meantime (a common source of pain). You can't use that option within a transaction, however, so Nandi uses the `disable_ddl_transaction!` macro. And we're ready to go.

But wait a minute - what about the foreign key one we started out with? The grizzled veterans among you know the workaround: add the constraint with the `NOT VALID` flag set, and then - in a separate follow-up transaction - validate the constraint. Nandi makes this easy:

```sh
rails generate nandi:foreign_key foos bars
```

We now have three new migration files:

```rb
# db/safe_migrations/20190611124816_add_reference_on_foos_to_bars.rb

class AddReferenceOnFoosToBars < Nandi::Migration
  def up
    add_column :foos, :bar_id, :bigint
  end

  def down
    remove_column :foos, :bar_id
  end
end

# db/safe_migrations/20190611124817_add_foreign_key_on_foos_to_bars.rb

class AddForeignKeyOnFoosToBars < Nandi::Migration
  def up
    add_foreign_key :foos, :bars
  end

  def down
    drop_constraint :foos, :foos_bars_fk
  end
end

# db/safe_migrations/20190611124818_validate_foreign_key_on_foos_to_bars.rb

class ValidateForeignKeyOnFoosToBars < Nandi::Migration
  def up
    validate_constraint :foos, :foos_bars_fk
  end

  def down; end
end
```

Which, when compiled, takes care of things in the right order:

```rb
# db/migrate/20190611124816_add_reference_on_foos_to_bars.rb

class AddReferenceOnFoosToBars < ActiveRecord::Migration[8.0]
  set_lock_timeout(5_000)
  set_statement_timeout(1_500)

  def up
    add_column(:foos, :bar_id, :bigint)
  end
  def down
    remove_column(:foos, :bar_id)
  end
end

# db/migrate/20190611124817_add_foreign_key_on_foos_to_bars.rb

class AddForeignKeyOnFoosToBars < ActiveRecord::Migration[8.0]
  set_lock_timeout(750)
  set_statement_timeout(1500)

  def up
    add_foreign_key(
      :foos,
      :bars,
      { name: :foos_bars_fk, validate: false },
    )
  end

  def down
    execute <<-SQL
    ALTER TABLE foos DROP CONSTRAINT foos_bars_fk
    SQL
  end
end

# db/migrate/20190611124818_validate_foreign_key_on_foos_to_bars.rb

# frozen_string_literal: true

class ValidateForeignKeyOnFoosToBars < ActiveRecord::Migration[8.0]
  set_lock_timeout(750)
  set_statement_timeout(1500)

  def up
    execute <<-SQL
    ALTER TABLE foos VALIDATE CONSTRAINT foos_bars_fk
    SQL
  end
end

```

## Class methods

### `.set_lock_timeout(timeout)`

Override the default lock timeout for the duration of the migration. For migrations that require AccessExclusive locks, this is limited to 750ms.

### `.set_statement_timeout(timeout)`

Override the default statement timeout for the duration of the migration. For migrations that require AccessExclusive locks, this is limited to 1500ms.

## Migration methods

### `#add_column(table, name, type, **kwargs)`

Adds a new column. Nandi will explicitly set the column to be NULL, as validating a new NOT NULL constraint can be very expensive on large tables and cause availability issues.

### `#add_foreign_key(table, target, column: nil, name: nil)`

Add a foreign key constraint. The generated SQL will include the NOT VALID parameter, which will prevent immediate validation of the constraint, which locks the target table for writes potentially for a long time. Use the separate #validate_constraint method, in a separate migration; this only takes a row-level lock as it scans through.

### `#add_index(table, fields, **kwargs)`

Adds a new index to the database.

Nandi will

- add the `CONCURRENTLY` option, which means the change takes a less restrictive lock at the cost of not running in a DDL transaction
- default to the `BTREE` index type, as it is commonly a good fit.

Because index creation is particularly failure-prone, and because we cannot run in a transaction and therefore risk partially applied migrations that (in a Rails environment) require manual intervention, Nandi Validates that, if there is a add_index statement in the migration, it must be the only statement.

### `#create_table(table) {|columns_reader| ... }`

Creates a new table. Yields a ColumnsReader object as a block, to allow adding columns.

Examples:

```rb
create_table :widgets do |t|
  t.text :foo, default: true
end
```

### `#add_reference(table, ref_name, **extra_args)`

Adds a new reference column. Nandi will validate that the foreign key flag is not set to true; use `add_foreign_key` and `validate_foreign_key` instead! Nandi will also set the `index: false` flag, as index creation is unsafe unless done concurrently in a separate migration.

### `#remove_reference(table, ref_name, **extra_args)`

Removes a reference column.

### `#remove_column(table, name, **extra_args)`

Remove an existing column.

### `#drop_constraint(table, name)`

Drops an existing constraint.

### `#remove_not_null_constraint(table, column)`

Drops an existing NOT NULL constraint. Please not that this migration is not safely reversible; to enforce NOT NULL like behaviour, use a CHECK constraint and validate it in a separate migration.

### `#change_column_default(table, column, value)`

Changes the default value for this column when new rows are inserted into the table.

### `#remove_index(table, target)`

Drop an index from the database.

Nandi will add the `CONCURRENTLY` option, which means the change takes a less restrictive lock at the cost of not running in a DDL transaction.
Because we cannot run in a transaction and therefore risk partially applied migrations that (in a Rails environment) require manual intervention, Nandi Validates that, if there is a remove_index statement in the migration, it must be the only statement.

### `#drop_table(table)`

Drops an existing table.

### `#irreversible_migration`

Raises `ActiveRecord::IrreversibleMigration` error.

## Generators

Some schema changes need to be split across two migration files. Whenever you want to add a constraint to a column, you'll have to do this to avoid locking the table while Postgres validates that all existing data meets the constraint.

For some of the most common cases, we provide a Rails generator that generates both files for you.

All generators support multi-database mode with the `--database` option (see Multi-Database Support section below).

### Not-null checks

To generate migration files for a not-null check, run this command:

```bash
rails generate nandi:not_null_check foos bar
```

This will generate two files:

```
db/safe_migrations/20190424123727_add_not_null_check_on_bar_to_foos.rb
db/safe_migrations/20190424123728_validate_not_null_check_on_bar_to_foos.rb
```

From there, you can simply `rails generate nandi:compile` as usual and you're done!

### Foreign key constraints

You may have spotted this generator in our worked example above. We've added it to this reference section too for completeness.

The simplest version of our foreign key migration generator is:

```
rails generate nandi:foreign_key foos bars
```

It will generate three files like these:

```
db/safe_migrations/20190424123726_add_reference_on_foos_to_bars.rb
db/safe_migrations/20190424123727_add_foreign_key_on_bars_to_foos.rb
db/safe_migrations/20190424123728_validate_foreign_key_on_bars_to_foos.rb
```

If you're adding the constraint to a column that already exists, you can use the `--no-create-column` flag to skip the first migration:

```
rails generate nandi:foreign_key foos bars --no-create-column
```

If your foreign key column is named differently, you can override it with the `--column` flag as seen in this example:

```
rails generate nandi:foreign_key foos bar --no-create-column --column special_bar_ids
```

We generate the name of your foreign key for you. If you want or need to override it (e.g. if it exceeds the max length of a constraint name in Postgres), you can use the `--name` flag:

```
rails generate nandi:foreign_key foos bar --name my_fk
```

## Configuration

Nandi can be configured in various ways, typically in an initializer:

```rb
# Single database configuration
Nandi.configure do |config|
  config.migration_directory = "db/safe_migrations"
  config.lock_timeout = 1_000
end

# Multi-database configuration (see Multi-Database Support section below)
Nandi.configure do |config|
  config.register_database(:primary)
  config.register_database(:analytics,
    migration_directory: "db/analytics_safe_migrations",
    output_directory: "db/analytics_migrate"
  )
end
```

The configuration parameters are as follows for setting Nandi up for a single database.

### `access_exclusive_lock_timeout_limit` (Integer)

The maximum lock timeout for migrations that take an ACCESS EXCLUSIVE lock and therefore block all reads and writes. Default: 5,000ms.

### `access_exclusive_statement_timeout_limit` (Integer)

The maximum statement timeout for migrations that take an ACCESS EXCLUSIVE lock and therefore block all reads and writes. Default: 1,500ms.

### `concurrent_statement_timeout_limit` (Integer)

The minimum statement timeout for migrations that take place concurrently. Default: 3,600,000ms (ie, 3 hours).

### `lock_timeout` (Integer)

The default lock timeout for migrations. Can be overridden by way of the `set_lock_timeout` class method in a given migration. Default: 5,000ms.

### `migration_directory` (String)

The directory for Nandi migrations. Default: `db/safe_migrations`.

### `output_directory` (String)

The directory for output files. Default: `db/migrate`.

### `renderer` (Class)

The rendering backend used to produce output. The only supported option at current is `Nandi::Renderers::ActiveRecord`, which produces ActiveRecord migrations.

### `statement_timeout` (Integer)

The default statement timeout for migrations that take permissive locks. Can be overridden by way of the `set_statement_timeout` class method in a given migration. Default: 10,800,000ms (ie, 3 hours).

### `access_exclusive_statement_timeout` (Integer)

The default statement timeout for migrations that take ACCESS EXCLUSIVE locks. Can be overridden by way of the `set_statement_timeout` class method in a given migration. Default: 1500ms.

### `compile_files` (String)

The files to compile when the compile generator is run. Default: `all`

May be one of the following:

- 'all' compiles all files
- 'git-diff' only files changed since last commit
- a full or partial version timestamp, eg '20190101010101', '20190101'
- a timestamp range , eg '>=20190101010101'

### `lockfile_directory` (String)

The directory where .nandilock.yml will be stored. Default: `db/` in working directory.

#post_process {|migration| ... }

Register a block to be called on output, for example a code formatter. Whatever is returned will be written to the output file.

```rb
config.post_process { |migration| MyFormatter.format(migration) }
```

#register_method(name, klass)

Register a custom DDL method.

Parameters:

`name` (Symbol) - The name of the method to create. This will be monkey-patched into Nandi::Migration.

`klass` (Class) — The class to initialise with the arguments to the method. It should define a `template` instance method which will return a subclass of Cell::ViewModel from the Cells templating library and a `procedure` method that returns the name of the method. It may optionally define a `mixins` method, which will return an array of `Module`s to be mixed into any migration that uses this method.

## Multi-Database Support

Nandi 2.0+ supports managing migrations for multiple databases within a single Rails application. 

**Note:** Single database configurations continue to work without any changes. Multi-database support is fully backward compatible.

### Configuring Multiple Databases

Instead of setting configuration values directly, register each database with its own configuration. If no values are specified, the existing defaults will be used.

**Database-specific options** (passed to `register_database`):
These options can be set individually for each database. **All are optional** - if not specified, the standard Nandi defaults are used:

- `migration_directory`: Where Nandi migrations are stored (default: `"db/safe_migrations"` for primary, `"db/<name>_safe_migrations"` for others)
- `output_directory`: Where compiled ActiveRecord migrations go (default: `"db/migrate"` for primary, `"db/<name>_migrate"` for others)
- `lockfile_name`: Name of the lockfile for this database (default: `".nandilock.yml"` for primary, `".<name>_nandilock.yml"` for others)
- `default`: Mark this database as the default when not named `:primary` (default: `false`)
- `access_exclusive_lock_timeout`: Timeout for ACCESS EXCLUSIVE locks (default: 5,000ms)
- `access_exclusive_statement_timeout`: Statement timeout for ACCESS EXCLUSIVE operations (default: 1,500ms)
- `access_exclusive_lock_timeout_limit`: Maximum allowed lock timeout (default: 5,000ms)
- `access_exclusive_statement_timeout_limit`: Maximum allowed statement timeout (default: 1,500ms)
- `concurrent_lock_timeout_limit`: Minimum timeout for concurrent operations (default: 3,600,000ms / 1 hour)
- `concurrent_statement_timeout_limit`: Minimum statement timeout for concurrent operations (default: 3,600,000ms / 1 hour)

**Global options** (set via config accessors):

These options apply to all databases:

- `config.lockfile_directory`: Directory where all lockfiles are stored (default: `"db"`)
- `config.compile_files`: Filter for which files to compile (default: `"all"`)
- `config.renderer`: Rendering backend (default: `Nandi::Renderers::ActiveRecord`)
- `config.post_process { |migration| ... }`: Optional post-processing block for formatting

```rb
# Minimal configuration - primary uses all defaults
Nandi.configure do |config|
  config.register_database(:primary)  # Uses all default paths and settings

  config.register_database(:analytics)

  # Global options (apply to all databases)
  config.lockfile_directory = "db"
  config.compile_files = "all"
end

# Full example with both database-specific and global options
Nandi.configure do |config|
  # Primary database (automatically becomes default)
  # If no values are specified, uses the standard defaults:
  # - migration_directory: "db/safe_migrations"
  # - output_directory: "db/migrate"
  # - lockfile_name: ".nandilock.yml"
  # - All timeout values use their defaults
  config.register_database(:primary,
    access_exclusive_lock_timeout: 5_000  # Only override what you need
  )

  # Analytics database with custom paths and relaxed timeouts
  config.register_database(:analytics,
    migration_directory: "db/analytics_safe_migrations",
    output_directory: "db/analytics_migrate",
    lockfile_name: ".analytics_nandilock.yml",
    access_exclusive_lock_timeout: 30_000,
    access_exclusive_statement_timeout: 10_000,
    concurrent_statement_timeout_limit: 7_200_000
  )

  # Global configuration options (apply to all databases)
  config.lockfile_directory = "db"       # Where all lockfiles are stored
  config.compile_files = "all"           # Filter for compilation
  config.renderer = Nandi::Renderers::ActiveRecord  # Optional, this is the default

  # Optional post-processing for all compiled migrations
  config.post_process do |migration|
    # Format, lint, etc.
    migration
  end
end
```

### Directory Structure

Each database maintains its own directory structure. The primary database uses the default paths if not specified:

```
db/
├── safe_migrations/              # Primary database (default path)
│   └── 20250901_add_users.rb
├── migrate/                     # Primary database (default path)
│   └── 20250901_add_users.rb
├── .nandilock.yml                # Primary database (default)
│
├── analytics_safe_migrations/    # Analytics database
│   └── 20250902_add_events.rb
├── analytics_migrate/
│   └── 20250902_add_events.rb
├── .analytics_nandilock.yml
│
├── reporting_safe_migrations/    # Reporting database
│   └── 20250903_add_reports.rb
├── reporting_migrate/
│   └── 20250903_add_reports.rb
└── .reporting_nandilock.yml
```

### Using Generators with Multiple Databases

All Nandi generators accept a `--database` option to specify which database to target:

```bash
# Generate for primary database (default)
rails generate nandi:migration create_users_table

# Generate for analytics database
rails generate nandi:migration create_events_table --database=analytics
```

### Compiling Migrations

The compile generator can compile all databases or a specific one:

```bash
# Compile all databases
rails generate nandi:compile

# Compile specific database with filter
rails generate nandi:compile --database=analytics --files=git-diff
```

### Default Database

- If you register a database named `:primary`, it automatically becomes the default per rails conventions
- Otherwise, mark a database as default with `default: true`
- Generators without `--database` option use the default database
- Single database configurations work without changes

## `.nandiignore`

To protect people from writing unsafe migrations, we provide a script [`nandi-enforce`](https://github.com/gocardless/nandi/blob/master/exe/nandi-enforce) that ensures all migrations in the specified directories are safe migrations generated by Nandi.

In the off cases where you need to write a migration by hand, add a `.nandiignore` to the root of your repository with your migration files:

```
db/migrate/20190324144824_my_handwritten_migration.rb
db/migrate/20190327130801_another_handwritten_migration.rb
db/migrate/20190327134957_one_more_handwritten_migration.rb
```

## Why Nandi?

You may have noticed a GIF of an adorable baby elephant above. This elephant is called Nandi, and she was the star of many an internal presentation slide here at GoCardless. Of course, Postgres is elephant-themed; but it is sometimes an angry elephant, motivating the creation of gems like this one. What better mascot than a harmless, friendly calf?

## Generate documentation

```sh
bundle exec yard
```

## Run tests

```sh
bundle exec rspec
```
