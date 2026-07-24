# Design: Configurable `concurrently` for `remove_index`

## Problem

`Nandi::Instructions::RemoveIndex` unconditionally sets `algorithm: :concurrently` on
every `remove_index` call (`lib/nandi/instructions/remove_index.rb:17-20`). There is
no way to opt out, globally, per-database, or per-call.

## Goals

1. Add a per-database config option to control the default: whether `remove_index`
   uses `CONCURRENTLY`.
2. Allow overriding that default per-call via a `concurrently:` keyword argument on
   `Migration#remove_index`.
3. Correctly model the Postgres locking behavior of a non-concurrent `DROP INDEX`
   (`ACCESS EXCLUSIVE`, vs. `SHARE` for the concurrent form) so existing timeout
   validation and generated `set_lock_timeout`/`set_statement_timeout` calls stay
   accurate.
4. Fix `should_disable_ddl_transaction?` so it no longer forces
   `disable_ddl_transaction!` for a `remove_index` that isn't actually concurrent.

## Non-goals

- Changing `add_index` behavior (it remains always concurrent).
- Any change to the "must be the only statement in the migration" constraint (this
  constraint only applies to `add_index` today; it's untouched).

## Background: an existing gap this design also fixes

Making the new option genuinely per-database requires `Nandi::Migration` instances
to know which database they were compiled for. Today they don't:

- `Nandi::Config` getters (`concurrent_lock_timeout`, `access_exclusive_lock_timeout`,
  etc.) already accept an optional `database_name` argument and resolve to the right
  `MultiDatabase::Database`.
- But every call site inside `lib/nandi/migration.rb`, `lib/nandi/validator.rb`, and
  `lib/nandi/timeout_policies/*.rb` calls these getters with **no** `database_name`,
  so they always silently resolve to the *default* database's config — even when
  compiling a migration for a non-default database.
- `CompiledMigration` (`lib/nandi/compiled_migration.rb`) already knows the correct
  `db_name`/`db_config` for a given migration file, but never passes it to
  `Migration.new`.

This design threads `database_name` through `Migration#initialize` and updates all
the internal config lookups to use it, which is required for the new
`remove_index_concurrently` option to be genuinely per-database, and as a side
effect fixes the existing timeout-config resolution gap for multi-database setups.

## Design

### 1. Config: `remove_index_concurrently`

`MultiDatabase::Database` (`lib/nandi/multi_database.rb`):
- New `attr_accessor :remove_index_concurrently`, defaulting to `true`.
- Set in `initialize` from `config[:remove_index_concurrently]`, defaulting to `true`
  if not provided (preserves current behavior for all existing configs).

`Nandi::Config` (`lib/nandi/config.rb`):
- New getter: `def remove_index_concurrently(database_name = nil) = config(database_name).remove_index_concurrently`
- New setter delegated to `:default` (alongside the existing timeout setters), so
  single-database-style configuration keeps working:
  ```ruby
  Nandi.configure do |config|
    config.remove_index_concurrently = false
  end
  ```
- Multi-database style:
  ```ruby
  Nandi.configure do |config|
    config.register_database(:primary)
    config.register_database(:analytics, remove_index_concurrently: false)
  end
  ```

### 2. `Migration` gains database context

`lib/nandi/migration.rb`:
- `initialize(validator, database_name: nil)` — stores `@database_name`, exposed via
  a public `attr_reader :database_name` (needed by `TimeoutPolicies::AccessExclusive`,
  `TimeoutPolicies::Concurrent`, and `Validator`).
- All internal config lookups updated to pass it through:
  - `disable_lock_timeout?` / `disable_statement_timeout?`:
    `Nandi.config.concurrent_lock_timeout(database_name)`,
    `Nandi.config.concurrent_statement_timeout(database_name)`
  - `default_statement_timeout` / `default_lock_timeout`:
    `Nandi.config.concurrent_statement_timeout(database_name)`,
    `Nandi.config.access_exclusive_statement_timeout(database_name)`,
    `Nandi.config.concurrent_lock_timeout(database_name)`,
    `Nandi.config.access_exclusive_lock_timeout(database_name)`

`lib/nandi/timeout_policies/access_exclusive.rb` and
`lib/nandi/timeout_policies/concurrent.rb`:
- `statement_timeout_maximum`/`lock_timeout_maximum`/`minimum_lock_timeout`/
  `minimum_statement_timeout` now call
  `Nandi.config.access_exclusive_statement_timeout_max(migration.database_name)` (etc.),
  using the `migration` each class already holds.

`lib/nandi/validator.rb`:
- `statement_timeout_is_within_acceptable_bounds` and
  `lock_timeout_is_within_acceptable_bounds` pass `migration.database_name` to
  `Nandi.config.access_exclusive_statement_timeout_max` /
  `Nandi.config.access_exclusive_lock_timeout_max`.

`lib/nandi/compiled_migration.rb`:
- `migration` method passes the known database name through:
  ```ruby
  @migration ||= class_name.camelize.constantize.new(Nandi.validator, database_name: db_name)
  ```

**Backward compatibility:** `database_name` defaults to `nil` everywhere, and every
config getter already treats `nil` as "use the default database" — identical to
today's behavior. Existing direct instantiations (`SomeMigration.new(validator)`,
used throughout specs) are unaffected.

### 3. `remove_index` per-call override

`lib/nandi/migration.rb`:
```ruby
def remove_index(table, target, concurrently: nil)
  concurrently = Nandi.config.remove_index_concurrently(database_name) if concurrently.nil?

  current_instructions << Instructions::RemoveIndex.new(
    table: table,
    field: target,
    concurrently: concurrently,
  )
end
```

### 4. `Instructions::RemoveIndex`

`lib/nandi/instructions/remove_index.rb`:
```ruby
def initialize(table:, field:, concurrently: true)
  @table = table
  @field = field
  @concurrently = concurrently
end

def extra_args
  base = field.is_a?(Hash) ? field.dup : { column: columns }
  concurrently ? base.merge(algorithm: :concurrently) : base
end

def lock
  concurrently ? Nandi::Migration::LockWeights::SHARE : Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
end

def concurrent?
  concurrently
end

private

attr_reader :field, :concurrently
```

No change to `RemoveIndexValidator` (still just checks for `:name` or `:column` in
`extra_args`, both still present either way).

### 5. Lock/timeout policy routing (no changes needed)

`TimeoutPolicies.policy_for` already branches on `instruction.lock` first:
```ruby
def self.policy_for(instruction)
  case instruction.lock
  when Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE
    AccessExclusive
  else
    share_policy_for(instruction)
  end
end
```
A non-concurrent `remove_index` now returns `ACCESS_EXCLUSIVE` from `#lock`, so it's
automatically routed to the `AccessExclusive` policy — which enforces short
`access_exclusive_*` timeouts and disallows `disable_lock_timeout!`/
`disable_statement_timeout!`, exactly like any other exclusive-locking instruction
(e.g. `remove_column`, `add_foreign_key`). A concurrent `remove_index` (`lock ==
SHARE`) continues to route through `share_policy_for`, which already includes
`:remove_index` in `CONCURRENT_OPERATIONS` — unchanged.

### 6. `should_disable_ddl_transaction?` fix

`lib/nandi/instructions/add_index.rb`:
```ruby
def concurrent?
  true
end
```

`lib/nandi/renderers/active_record/generate.rb`:
```ruby
def should_disable_ddl_transaction?
  [*up_instructions, *down_instructions].any? { |i| i.respond_to?(:concurrent?) && i.concurrent? }
end
```
Replaces the previous `procedure.to_s.include?("index")` string match, which
incorrectly forced `disable_ddl_transaction!` for a non-concurrent `remove_index`
even when nothing in the migration required it.

## Example usage

```ruby
# Global-style (single database)
Nandi.configure do |config|
  config.remove_index_concurrently = false
end

# Per-database
Nandi.configure do |config|
  config.register_database(:primary)
  config.register_database(:analytics, remove_index_concurrently: false)
end

# Per-call override, regardless of config default
class RemoveFooIndex < Nandi::Migration
  def up
    remove_index :payments, :foo, concurrently: false
  end
end
```

## Testing

- `spec/nandi/instructions/remove_index_spec.rb`: cover `concurrently: true` (default,
  existing behavior), `concurrently: false` (no `algorithm` key, `lock` is
  `ACCESS_EXCLUSIVE`, `concurrent?` is `false`).
- `spec/nandi/migration_spec.rb`: `remove_index` resolves the config default per
  database, and per-call `concurrently:` overrides it.
- `spec/nandi/config_spec.rb` / `spec/nandi/multi_database_spec.rb` (whichever holds
  multi-db config specs): `remove_index_concurrently` registrable per database,
  defaults to `true`.
- `spec/nandi/timeout_policies/*_spec.rb`: a non-concurrent `remove_index` migration
  is validated against `access_exclusive_*` bounds, not `concurrent_*` bounds.
- `spec/nandi/renderers/active_record_spec.rb`: rendered output for
  `concurrently: false` omits `algorithm: :concurrently` and, combined with another
  instruction on the same table, does **not** emit `disable_ddl_transaction!`.
- A multi-database compile spec (extending existing patterns in
  `spec/nandi/compiled_migration_spec.rb`) verifying a migration compiled for a
  non-default database resolves that database's `access_exclusive_*` /
  `concurrent_*` / `remove_index_concurrently` values, not the primary's.

## Documentation

Update `README.md`:
- `remove_index` section: document the `concurrently:` keyword argument.
- Multi-Database `register_database` options list: add `remove_index_concurrently`.
