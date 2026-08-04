# Thread `database_name` through Migration/Validator/TimeoutPolicies — Design

## Background

`Nandi::Config` supports per-database configuration via `register_database(name, config)`, and every relevant config lookup method already accepts an optional `database_name` parameter (defaulting to the primary/default database when omitted):

```ruby
def access_exclusive_lock_timeout(database_name = nil) = config(database_name).access_exclusive_lock_timeout
def access_exclusive_lock_timeout_max(database_name = nil) = config(database_name).access_exclusive_lock_timeout_max
def access_exclusive_statement_timeout(database_name = nil) = config(database_name).access_exclusive_statement_timeout
def access_exclusive_statement_timeout_max(database_name = nil) = config(database_name).access_exclusive_statement_timeout_max
def concurrent_lock_timeout_min(database_name = nil) = config(database_name).concurrent_lock_timeout_min
def concurrent_statement_timeout_min(database_name = nil) = config(database_name).concurrent_statement_timeout_min
def concurrent_lock_timeout(database_name = nil) = config(database_name).concurrent_lock_timeout
def concurrent_statement_timeout(database_name = nil) = config(database_name).concurrent_statement_timeout
def yugabyte_database?(database_name = nil) = config(database_name).yugabyte_database
```

The problem: nothing in the migration-compilation pipeline ever passes a `database_name`. `Nandi::CompiledMigration` already knows which database a migration belongs to (`db_name`/`db_config`), but it constructs `Migration` with no database context:

```ruby
def migration
  @migration ||= class_name.camelize.constantize.new(Nandi.validator)
end
```

As a result, every timeout/config lookup made during validation always resolves against the default database, even for migrations compiled against a non-default database (e.g. a YugabyteDB-configured database).

This mirrors work previously attempted in PR #156 (`remove-index-concurrently-config`, closed/unmerged). That PR's `database_name`-threading mechanism was sound; it was closed because of an unrelated design flaw in the `remove_index concurrently:` feature it also introduced (a reviewer noted that per-statement timeout validation doesn't match Nandi's per-migration-file timeout model). This design reuses the threading mechanism only, as fresh commits on a new branch off `master`, independent of the `remove_index concurrently:` work.

## Goal

Thread `database_name` from `CompiledMigration` through `Migration` to every place that currently calls a per-database `Nandi.config` lookup method without a `database_name` argument, so config resolves against the correct database.

## Non-goals

- The `remove_index concurrently:` feature from PR #156 — out of scope, unrelated, and was never merged due to a design flaw specific to that feature.
- `Validator#statement_timeout_is_within_acceptable_bounds` / `#lock_timeout_is_within_acceptable_bounds` (`lib/nandi/validator.rb:74-84`) — these are private methods with no callers (dead code; the live timeout-check path is `Validator#validate_timeouts` → `Nandi::Validation::TimeoutValidator.call` → `Nandi::TimeoutPolicies`). Left untouched; not this change's dead code to clean up.
- Any use of `database_name` inside instruction-level validators (`Nandi::Validation::EachValidator`, `AddIndexYbValidator`, etc.) — that threading is separate follow-up work that will build on top of this PR from the `yb-add-index` branch.

## Design

### Call chain

```
CompiledMigration#migration
  → Migration.new(validator, database_name: db_name)
    → Migration#database_name (new attr_reader)
      → Migration#disable_lock_timeout?
      → Migration#disable_statement_timeout?
      → Migration#default_statement_timeout
      → Migration#default_lock_timeout
      → TimeoutPolicies::AccessExclusive#statement_timeout_maximum (via migration.database_name)
      → TimeoutPolicies::AccessExclusive#lock_timeout_maximum (via migration.database_name)
      → TimeoutPolicies::Concurrent#minimum_lock_timeout (via migration.database_name)
      → TimeoutPolicies::Concurrent#minimum_statement_timeout (via migration.database_name)
```

`TimeoutPolicies::AccessExclusive`/`Concurrent` are reached via `Validator#validate_timeouts` → `Nandi::Validation::TimeoutValidator.call(migration)`, which already has the `migration` object in hand — no new parameter needed on that path, since `TimeoutPolicies` reads `migration.database_name` directly.

### File-by-file changes

**`lib/nandi/migration.rb`**
- `initialize(validator, database_name: nil)` — stores `@database_name = database_name`.
- New `attr_reader :database_name` (marked `@api private`, matching the existing `up_instructions`/`down_instructions` convention).
- `disable_lock_timeout?` / `disable_statement_timeout?`: pass `database_name` into `Nandi.config.concurrent_lock_timeout` / `Nandi.config.concurrent_statement_timeout`.
- `default_statement_timeout` / `default_lock_timeout`: pass `database_name` into all four `Nandi.config.concurrent_*` / `Nandi.config.access_exclusive_*` calls.

**`lib/nandi/compiled_migration.rb`**
- `migration` method: `class_name.camelize.constantize.new(Nandi.validator, database_name: db_name)`.

**`lib/nandi/timeout_policies/access_exclusive.rb`**
- `statement_timeout_maximum`: `Nandi.config.access_exclusive_statement_timeout_max(migration.database_name)`.
- `lock_timeout_maximum`: `Nandi.config.access_exclusive_lock_timeout_max(migration.database_name)`.

**`lib/nandi/timeout_policies/concurrent.rb`**
- `minimum_lock_timeout`: `Nandi.config.concurrent_lock_timeout_min(migration.database_name)`.
- `minimum_statement_timeout`: `Nandi.config.concurrent_statement_timeout_min(migration.database_name)`.

### Backward compatibility

`database_name: nil` is the default at every layer, and `Nandi.config`'s lookup methods already treat `database_name = nil` as "use the default database." All existing call sites — the 50+ `Migration.new(validator)` calls in `spec/nandi/migration_spec.rb`, and the single production call site (now updated) in `CompiledMigration` — continue to work unmodified.

## Testing

- `spec/nandi/migration_spec.rb`: add coverage that `database_name` is stored and that `disable_lock_timeout?`/`disable_statement_timeout?`/`default_statement_timeout`/`default_lock_timeout` resolve config against the passed-in database (using `register_database` with distinct per-database timeout config, following the existing multi-db test patterns in `spec/nandi/config_spec.rb`).
- `spec/nandi/compiled_migration_spec.rb`: assert `Migration.new` is called with `database_name: db_name`.
- `spec/nandi/timeout_policies/access_exclusive_spec.rb` and `concurrent_spec.rb`: assert the timeout maximum/minimum methods resolve against `migration.database_name` (via a double or real `Migration` instance with a non-default `database_name`).

## Out of scope / deferred

- Threading `database_name` into `Validator::EachValidator` and `AddIndexYbValidator` — deferred to follow-up work on `yb-add-index`, which will rebase on this branch once merged.
- Cleanup of the dead `statement_timeout_is_within_acceptable_bounds`/`lock_timeout_is_within_acceptable_bounds` methods in `validator.rb` — noted here for visibility, not addressed by this change.
