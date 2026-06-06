# Changelog

## v2.1.0 (2026-06-05)

### New features

- Add `concurrent_lock_timeout` and `concurrent_statement_timeout` as optional
  global config options. When set, concurrent migrations (`add_index`,
  `remove_index`) will emit `set_lock_timeout`/`set_statement_timeout` in their
  compiled output instead of `disable_lock_timeout!`/`disable_statement_timeout!`.
  Per-migration `set_lock_timeout`/`set_statement_timeout` calls continue to
  take precedence. Defaults to `nil`, so existing behaviour is fully preserved.

  ```ruby
  Nandi.configure do |config|
    config.register_database(:primary,
      migration_directory: "db/safe_migrations",
      output_directory: "db/migrate",
      concurrent_lock_timeout: 120_000,      # 2 minutes
      concurrent_statement_timeout: 600_000) # 10 minutes
  end
  ```

## v2.0.1 (2025-08-12)

- Allow idempotent database registration for Rails reloading.

## v2.0.0 (2025-08-12)

- Add multi-database support via `register_database`.

## v1.0.1

- Bug fixes.

## v1.0.0

- Initial stable release.
