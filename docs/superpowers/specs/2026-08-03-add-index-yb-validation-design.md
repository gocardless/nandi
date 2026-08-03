# Design: Validate `add_index_yb` requires `yugabyte_database` config

## Problem

`add_index_yb` (`Nandi::Instructions::Yugabyte::AddIndexYb`) is a migration DSL
method that generates YugabyteDB-specific SQL (hash-bucketed indexes via
`yb_hash_code`). It should only be usable when the target database is
configured as a YugabyteDB database. There is currently no validation
enforcing this, and the underlying `yugabyte_database` config flag
(referenced by `Nandi::Config#yugabyte_database?`) isn't actually implemented
on `MultiDatabase::Database` — calling it today raises `NoMethodError`.

## Scope

- Implement the missing `yugabyte_database` config attribute.
- Add validation that fails a migration using `add_index_yb` when
  `yugabyte_database?` is false for the (default) configured database.
- Build the check as a small reusable mixin, since the `Yugabyte` instruction
  namespace suggests more YB-only instructions may be added later.

Out of scope: multi-database-aware lookups (see below), any other
YugabyteDB-specific instructions beyond `add_index_yb`.

## Design

### 1. `MultiDatabase::Database#yugabyte_database`

Add to `lib/nandi/multi_database.rb`:

```ruby
attr_reader :yugabyte_database
```

Set in `initialize`, alongside the existing `@default` assignment:

```ruby
@yugabyte_database = config[:yugabyte_database] == true
```

Defaults to `false` when not specified, matching the existing boolean-flag
pattern used for `@default`.

This makes the existing `Nandi::Config#yugabyte_database?(database_name = nil)`
(`lib/nandi/config.rb:89`) work correctly.

Note: as with other per-migration config lookups (e.g.
`access_exclusive_lock_timeout`), `Nandi::Migration` and validators have no
concept of "which database" a migration targets, so the check will call
`Nandi.config.yugabyte_database?` with no database name, which resolves to
the default/primary database's config. This is consistent with existing
behavior elsewhere in the codebase and is not a new limitation introduced by
this change.

### 2. Reusable validation mixin

New file `lib/nandi/validation/requires_yugabyte_database.rb`:

```ruby
# frozen_string_literal: true

module Nandi
  module Validation
    module RequiresYugabyteDatabase
      def assert_yugabyte_database
        assert(
          Nandi.config.yugabyte_database?,
          "#{instruction.procedure}: this instruction can only be used when the target database is " \
          "configured as YugabyteDB (pass `yugabyte_database: true` to `register_database`).",
        )
      end
    end
  end
end
```

Depends on `instruction` and `assert` being available on the including class
(both already present on every `Nandi::Validation::*Validator`, since they
all include `FailureHelpers` and expose an `attr_reader :instruction`).

Any future YugabyteDB-only instruction validator can include this module and
call `assert_yugabyte_database` instead of duplicating the check.

### 3. `AddIndexYbValidator`

New file `lib/nandi/validation/add_index_yb_validator.rb`, following the
exact shape of the existing `AddIndexValidator` / `RemoveIndexValidator`:

```ruby
# frozen_string_literal: true

require "nandi/validation/failure_helpers"
require "nandi/validation/requires_yugabyte_database"

module Nandi
  module Validation
    class AddIndexYbValidator
      include Nandi::Validation::FailureHelpers
      include Nandi::Validation::RequiresYugabyteDatabase

      def self.call(instruction)
        new(instruction).call
      end

      def initialize(instruction)
        @instruction = instruction
      end

      def call
        assert_yugabyte_database
      end

      attr_reader :instruction
    end
  end
end
```

### 4. Wiring

- `lib/nandi/validation.rb`: add `require`s for the two new files.
- `lib/nandi/validation/each_validator.rb`: add a `when :add_index_yb`
  branch routing to `AddIndexYbValidator.call(instruction)`.

### 5. Tests

- `spec/nandi/multi_database_spec.rb`: `yugabyte_database` defaults to
  `false`; is `true` when passed to `register_database`.
- `spec/nandi/config_spec.rb`: `yugabyte_database?` delegates to the
  configured database.
- New `spec/nandi/validation/add_index_yb_validator_spec.rb` (mirrors
  `add_index_validator_spec.rb`): failure when `yugabyte_database?` is false
  (default/unset), success when true.
- `spec/nandi/validation/each_validator_spec.rb`: add a case asserting
  `:add_index_yb` routes to `AddIndexYbValidator`.

## Error message example

```
add_index_yb: this instruction can only be used when the target database is configured as YugabyteDB (pass `yugabyte_database: true` to `register_database`).
```

## Non-goals / follow-ups

- No README documentation changes are included; can be added separately if
  desired.
- No changes to how `Nandi.config.yugabyte_database?` resolves per-database
  in a multi-database setup — it follows the existing default-database-only
  convention used by other per-migration config lookups.
