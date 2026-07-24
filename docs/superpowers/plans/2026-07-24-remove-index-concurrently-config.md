# Configurable `concurrently` for `remove_index` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `remove_index` skip Postgres's `CONCURRENTLY` option, configurable per-database with a per-call override, while keeping lock/timeout validation and `disable_ddl_transaction!` generation accurate.

**Architecture:** Add a `remove_index_concurrently` boolean to Nandi's per-database config (default `true`, preserving today's behavior). Thread a `database_name` through `Migration` so config lookups that are already database-name-aware (but never actually passed one) resolve correctly for non-default databases. Give `RemoveIndex` a `concurrently` flag that changes its `extra_args`, `lock`, and adds a `concurrent?` predicate; route `should_disable_ddl_transaction?` off that predicate instead of a brittle string match on the procedure name.

**Tech Stack:** Ruby, RSpec, ActiveSupport (`delegate`), Cells/Tilt (ERB instruction templates).

## Global Constraints

- Default behavior must be unchanged: `remove_index_concurrently` defaults to `true` everywhere, `RemoveIndex#initialize` defaults `concurrently:` to `true`.
- `database_name` parameters/kwargs must default to `nil` everywhere they're introduced, and `nil` must continue to resolve to the default/primary database (existing `Nandi::Config`/`MultiDatabase` behavior) — this is required for backward compatibility with every existing direct `Migration.new(validator)` call (production and specs).
- `add_index` behavior is unchanged — always concurrent.
- The "must be the only statement in the migration" constraint is unchanged — it only applies to `add_index`.
- Follow existing code style in each file (frozen_string_literal comment, `# rubocop:disable/enable` markers where already present, RSpec `described_class`/`subject`/`let` conventions).
- Full test suite baseline before this work: **416 examples, 0 failures** (`bundle exec rspec`). Every task must keep the suite green.

---

### Task 1: Add `remove_index_concurrently` per-database config option

**Files:**
- Modify: `lib/nandi/multi_database.rb:5-93` (the `Database` class)
- Modify: `lib/nandi/config.rb:77-102`
- Test: `spec/nandi/multi_database_spec.rb` (new context inside `describe "Database"`, after the existing "with concurrent timeout defaults" context, which currently ends at line 301)

**Interfaces:**
- Produces: `MultiDatabase::Database#remove_index_concurrently` — reader, `Boolean`, defaults to `true`.
- Produces: `Nandi::Config#remove_index_concurrently(database_name = nil)` — `Boolean`.
- Produces: `Nandi::Config#remove_index_concurrently=` — setter, delegates to the default database (same pattern as `concurrent_lock_timeout=` etc).

- [ ] **Step 1: Write the failing tests**

In `spec/nandi/multi_database_spec.rb`, insert a new context immediately after the "with concurrent timeout defaults" context closes (currently the `end` on line 301) and before `context "with deprecated _limit config keys" do` (currently line 303):

```ruby
    context "with remove_index_concurrently" do
      let(:name) { :primary }

      context "when not configured" do
        let(:config) { {} }

        it "defaults to true" do
          expect(database.remove_index_concurrently).to be true
        end
      end

      context "when explicitly set to false" do
        let(:config) { { remove_index_concurrently: false } }

        it "returns false" do
          expect(database.remove_index_concurrently).to be false
        end
      end

      context "when explicitly set to true" do
        let(:config) { { remove_index_concurrently: true } }

        it "returns true" do
          expect(database.remove_index_concurrently).to be true
        end
      end
    end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/nandi/multi_database_spec.rb -e "remove_index_concurrently"`
Expected: FAIL with `NoMethodError: undefined method 'remove_index_concurrently'`

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/multi_database.rb`, add an accessor near the other concurrent-timeout accessors (after `concurrent_statement_timeout`, i.e. after line 64):

```ruby
      # Whether `remove_index` should use the `CONCURRENTLY` option by default. When
      # `false`, `remove_index` takes a brief ACCESS EXCLUSIVE lock instead of a SHARE
      # lock, and can therefore run inside a DDL transaction. Default: true.
      # @return [Boolean]
      attr_accessor :remove_index_concurrently
```

Then set its default in `timeout_limits` (the method that currently ends with `@concurrent_statement_timeout = config[:concurrent_statement_timeout]` on line 123):

```ruby
        @concurrent_lock_timeout = config[:concurrent_lock_timeout]
        @concurrent_statement_timeout = config[:concurrent_statement_timeout]
        @remove_index_concurrently = config.fetch(:remove_index_concurrently, true)
```

In `lib/nandi/config.rb`, add a getter alongside the other database-name-aware getters (after line 88, `concurrent_statement_timeout`):

```ruby
    def remove_index_concurrently(database_name = nil) = config(database_name).remove_index_concurrently
```

And add the setter to the existing `delegate` call (lines 92-102), alongside `:concurrent_statement_timeout=`:

```ruby
    delegate :migration_directory=,
             :output_directory=,
             :access_exclusive_lock_timeout=,
             :access_exclusive_lock_timeout_max=,
             :access_exclusive_statement_timeout=,
             :access_exclusive_statement_timeout_max=,
             :concurrent_lock_timeout_min=,
             :concurrent_statement_timeout_min=,
             :concurrent_lock_timeout=,
             :concurrent_statement_timeout=,
             :remove_index_concurrently=,
             to: :default
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/nandi/multi_database_spec.rb`
Expected: PASS, all examples in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/multi_database.rb lib/nandi/config.rb spec/nandi/multi_database_spec.rb
git commit -m "feat: add remove_index_concurrently per-database config option"
```

---

### Task 2: Thread `database_name` through `Migration#initialize`

**Files:**
- Modify: `lib/nandi/migration.rb:71-76`
- Test: `spec/nandi/migration_spec.rb` (new `describe "#database_name"` block)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Migration#initialize(validator, database_name: nil)`, `Migration#database_name` (public reader, `Symbol` or `nil`). Later tasks depend on this exact kwarg name and reader.

- [ ] **Step 1: Write the failing test**

Add to `spec/nandi/migration_spec.rb`, after the `describe "name"` block (after line 18):

```ruby
  describe "#database_name" do
    let(:subject_class) do
      Class.new(described_class) do
        def up; end
      end
    end

    context "when not provided" do
      subject(:migration) { subject_class.new(validator) }

      it "defaults to nil" do
        expect(migration.database_name).to be_nil
      end
    end

    context "when provided" do
      subject(:migration) { subject_class.new(validator, database_name: :analytics) }

      it "exposes the given database name" do
        expect(migration.database_name).to eq(:analytics)
      end
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/nandi/migration_spec.rb -e "#database_name"`
Expected: FAIL — `wrong number of arguments` (for the `database_name:` case) and/or `NoMethodError: undefined method 'database_name'`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/migration.rb`, replace:

```ruby
    # @param validator [Nandi::Validator]
    def initialize(validator)
      @validator = validator
      @instructions = Hash.new { |h, k| h[k] = InstructionSet.new([]) }
      validate
    end
```

with:

```ruby
    # @param validator [Nandi::Validator]
    # @param database_name [Symbol, nil] The database this migration is being compiled
    #   for. Used to resolve per-database config. Defaults to the default database.
    def initialize(validator, database_name: nil)
      @validator = validator
      @database_name = database_name
      @instructions = Hash.new { |h, k| h[k] = InstructionSet.new([]) }
      validate
    end

    # @api private
    attr_reader :database_name
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/nandi/migration_spec.rb`
Expected: PASS, all examples in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/migration.rb spec/nandi/migration_spec.rb
git commit -m "feat: thread database_name through Migration#initialize"
```

---

### Task 3: Use `database_name` in Migration's own timeout config lookups

**Files:**
- Modify: `lib/nandi/migration.rb:332-346` (`disable_lock_timeout?`, `disable_statement_timeout?`), `lib/nandi/migration.rb:378-392` (`default_statement_timeout`, `default_lock_timeout`)
- Test: `spec/nandi/migration_spec.rb` (new context inside the existing `describe "timeouts"` block)

**Interfaces:**
- Consumes: `Migration#database_name` (Task 2).
- Produces: no new public interface — internal behavior fix only.

- [ ] **Step 1: Write the failing test**

Add a new context to `spec/nandi/migration_spec.rb`, nested inside the existing `describe "timeouts"` block (after line 949, right after `subject(:migration) { subject_class.new(validator) }` and before `context "when the strictest lock is SHARE" do`). This needs its own `subject` since it instantiates with a `database_name:`:

```ruby
    context "when instantiated for a non-default database" do
      subject(:migration) { subject_class.new(validator, database_name: :analytics) }

      let(:subject_class) do
        Class.new(described_class) do
          def up
            validate_constraint :payments, :payments_mandates_fk
          end

          def down; end
        end
      end

      before do
        Nandi.config.register_database(:analytics, concurrent_lock_timeout: 999_000)
      end

      after do
        Nandi.instance_variable_set(:@config, nil)
      end

      it "resolves concurrent_lock_timeout from the analytics database, not the default" do
        expect(migration.lock_timeout).to eq(999_000)
        expect(migration.disable_lock_timeout?).to be(false)
      end
    end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/nandi/migration_spec.rb -e "non-default database"`
Expected: FAIL — `expected: 999000, got: nil` (or similar), because `disable_lock_timeout?`/`default_lock_timeout` currently call `Nandi.config.concurrent_lock_timeout` with no argument, always resolving to the default database instead of `:analytics`.

Note: `Nandi.config.register_database(:analytics, ...)` requires a `:primary` (or other `default: true`) database to already exist for multi-db validation, but `validate!` is only invoked explicitly elsewhere — registering a second database without a `:primary` one is fine for this test since nothing calls `config.validate!` here. If this test fails for an unrelated reason (e.g. "Database analytics already registered" from a prior example's leaked state), confirm the `after` hook above is resetting `Nandi.instance_variable_set(:@config, nil)`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/migration.rb`, replace:

```ruby
    def disable_lock_timeout?
      if self.class.lock_timeout.nil?
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_lock_timeout.nil?
      else
        false
      end
    end

    def disable_statement_timeout?
      if self.class.statement_timeout.nil?
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_statement_timeout.nil?
      else
        false
      end
    end
```

with:

```ruby
    def disable_lock_timeout?
      if self.class.lock_timeout.nil?
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_lock_timeout(database_name).nil?
      else
        false
      end
    end

    def disable_statement_timeout?
      if self.class.statement_timeout.nil?
        strictest_lock == LockWeights::SHARE && Nandi.config.concurrent_statement_timeout(database_name).nil?
      else
        false
      end
    end
```

And replace:

```ruby
    def default_statement_timeout
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_statement_timeout || Nandi.config.access_exclusive_statement_timeout
      else
        Nandi.config.access_exclusive_statement_timeout
      end
    end

    def default_lock_timeout
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_lock_timeout || Nandi.config.access_exclusive_lock_timeout
      else
        Nandi.config.access_exclusive_lock_timeout
      end
    end
```

with:

```ruby
    def default_statement_timeout
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_statement_timeout(database_name) ||
          Nandi.config.access_exclusive_statement_timeout(database_name)
      else
        Nandi.config.access_exclusive_statement_timeout(database_name)
      end
    end

    def default_lock_timeout
      if strictest_lock == LockWeights::SHARE
        Nandi.config.concurrent_lock_timeout(database_name) || Nandi.config.access_exclusive_lock_timeout(database_name)
      else
        Nandi.config.access_exclusive_lock_timeout(database_name)
      end
    end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/nandi/migration_spec.rb`
Expected: PASS, all examples in the file green (including the pre-existing "timeouts" contexts, which use `database_name: nil` implicitly and must still resolve to the default database's config).

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/migration.rb spec/nandi/migration_spec.rb
git commit -m "fix: resolve Migration's own timeout config lookups per-database"
```

---

### Task 4: Pass `database_name` from `CompiledMigration` to `Migration.new`

**Files:**
- Modify: `lib/nandi/compiled_migration.rb:52-54`
- Test: `spec/nandi/compiled_migration_spec.rb` (extend the existing "nil db_name handling" describe block, lines 125-153)

**Interfaces:**
- Consumes: `Migration#initialize(validator, database_name: nil)` (Task 2).
- Produces: `CompiledMigration#migration` now instantiates with the resolved `db_name`. No signature change to `CompiledMigration` itself.

- [ ] **Step 1: Write the failing tests**

In `spec/nandi/compiled_migration_spec.rb`, add assertions to both existing contexts inside `describe "nil db_name handling"` (lines 125-153):

```ruby
  describe "nil db_name handling" do
    context "when db_name is nil" do
      let(:db_name) { nil }

      it "defaults to primary database" do
        migration = described_class.new(file_name: valid_migration, db_name: nil)
        expect(migration.db_name).to eq(:primary)
      end

      it "uses primary database configuration" do
        migration = described_class.new(file_name: valid_migration, db_name: nil)
        expect(migration.output_path).to eq("db/migrate/#{valid_migration}")
      end

      it "instantiates the migration with the resolved database name" do
        compiled = described_class.new(file_name: valid_migration, db_name: nil)
        expect(compiled.migration.database_name).to eq(:primary)
      end
    end

    context "when db_name is explicitly provided" do
      before do
        Nandi.config.register_database(:analytics,
                                       migration_directory: base_path,
                                       output_directory: "db/analytics_migrate")
      end

      it "uses the specified database" do
        migration = described_class.new(file_name: valid_migration, db_name: :analytics)
        expect(migration.db_name).to eq(:analytics)
        expect(migration.output_path).to eq("db/analytics_migrate/#{valid_migration}")
      end

      it "instantiates the migration with the specified database name" do
        compiled = described_class.new(file_name: valid_migration, db_name: :analytics)
        expect(compiled.migration.database_name).to eq(:analytics)
      end
    end
  end
```

(Only the two new `it` blocks — "instantiates the migration with..." — are additions; the rest is unchanged context for reference.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/nandi/compiled_migration_spec.rb -e "instantiates the migration"`
Expected: FAIL — `expected: :primary, got: nil` / `expected: :analytics, got: nil`, since `CompiledMigration#migration` currently calls `.new(Nandi.validator)` with no `database_name`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/compiled_migration.rb`, replace:

```ruby
    def migration
      @migration ||= class_name.camelize.constantize.new(Nandi.validator)
    end
```

with:

```ruby
    def migration
      @migration ||= class_name.camelize.constantize.new(Nandi.validator, database_name: db_name)
    end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/nandi/compiled_migration_spec.rb`
Expected: PASS, all examples in the file green.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/compiled_migration.rb spec/nandi/compiled_migration_spec.rb
git commit -m "fix: pass resolved database_name from CompiledMigration to Migration.new"
```

---

### Task 5: Use `migration.database_name` in timeout policies and the validator

**Files:**
- Modify: `lib/nandi/timeout_policies/access_exclusive.rb:45-51`
- Modify: `lib/nandi/timeout_policies/concurrent.rb:55-61`
- Modify: `lib/nandi/validator.rb:74-84`
- Modify (fix broken doubles): `spec/nandi/timeout_policies/access_exclusive_spec.rb:15-20`, `spec/nandi/validator_spec.rb:16-22`, `spec/nandi/validation/timeout_validator_spec.rb:15-20`
- Test: `spec/nandi/timeout_policies/access_exclusive_spec.rb` (new context)

**Interfaces:**
- Consumes: `Migration#database_name` (Task 2).
- Produces: no new public interface — internal behavior fix, plus three previously-passing spec files updated so their `instance_double(Nandi::Migration, ...)` stubs include `database_name:` (required because `instance_double` is a verifying double: once `AccessExclusive`/`Concurrent`/`Validator` call `migration.database_name`, any double standing in for `Nandi::Migration` must stub that message or raise `#<Double (anonymous)> received unexpected message :database_name`).

- [ ] **Step 1: Write the failing test**

First, add `database_name: nil` to the existing `instance_double` in `spec/nandi/timeout_policies/access_exclusive_spec.rb`. Find:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout)
  end
```

Replace with:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout,
                    database_name: nil)
  end
```

Then add a new context to that same file demonstrating database-specific resolution, right after the existing `before` block that stubs `Nandi.config` (find the block ending `allow(Nandi.config).to receive(:access_exclusive_lock_timeout_max).and_return(750)` a second time — add this as a sibling `context` at the top level of the `describe` block, alongside `context "with an ACCESS EXCLUSIVE instruction" do`):

```ruby
  context "when the migration belongs to a non-default database" do
    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout,
                      database_name: :analytics)
    end

    before do
      allow(Nandi.config).to receive(:access_exclusive_statement_timeout_max).with(:analytics).and_return(200)
      allow(Nandi.config).to receive(:access_exclusive_lock_timeout_max).with(:analytics).and_return(100)
    end

    context "with too great a statement timeout for the analytics database" do
      let(:statement_timeout) { 201 }

      it { is_expected.to be_failure }
    end

    context "within the analytics database's bounds" do
      let(:statement_timeout) { 200 }
      let(:lock_timeout) { 100 }

      it { is_expected.to be_success }
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/nandi/timeout_policies/access_exclusive_spec.rb -e "non-default database"`
Expected: FAIL — the `before` block stubs `access_exclusive_statement_timeout_max` `.with(:analytics)`, but `AccessExclusive#statement_timeout_maximum` currently calls it with no arguments, so the stub never matches and RSpec raises `received :access_exclusive_statement_timeout_max with unexpected arguments` (or the un-stubbed no-arg call falls through to the real `Nandi.config`, which raises `ArgumentError: Missing database configuration for analytics`).

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/timeout_policies/access_exclusive.rb`, replace:

```ruby
      def statement_timeout_maximum
        Nandi.config.access_exclusive_statement_timeout_max
      end

      def lock_timeout_maximum
        Nandi.config.access_exclusive_lock_timeout_max
      end
```

with:

```ruby
      def statement_timeout_maximum
        Nandi.config.access_exclusive_statement_timeout_max(migration.database_name)
      end

      def lock_timeout_maximum
        Nandi.config.access_exclusive_lock_timeout_max(migration.database_name)
      end
```

In `lib/nandi/timeout_policies/concurrent.rb`, replace:

```ruby
      def minimum_lock_timeout
        Nandi.config.concurrent_lock_timeout_min
      end

      def minimum_statement_timeout
        Nandi.config.concurrent_statement_timeout_min
      end
```

with:

```ruby
      def minimum_lock_timeout
        Nandi.config.concurrent_lock_timeout_min(migration.database_name)
      end

      def minimum_statement_timeout
        Nandi.config.concurrent_statement_timeout_min(migration.database_name)
      end
```

In `lib/nandi/validator.rb`, replace:

```ruby
    def statement_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.statement_timeout <=
          Nandi.config.access_exclusive_statement_timeout_max
    end

    def lock_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.lock_timeout <=
          Nandi.config.access_exclusive_lock_timeout_max
    end
```

with:

```ruby
    def statement_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.statement_timeout <=
          Nandi.config.access_exclusive_statement_timeout_max(migration.database_name)
    end

    def lock_timeout_is_within_acceptable_bounds
      migration.strictest_lock != Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE ||
        migration.lock_timeout <=
          Nandi.config.access_exclusive_lock_timeout_max(migration.database_name)
    end
```

Now fix the two other specs whose `instance_double(Nandi::Migration, ...)` will otherwise break because `Validator#call` (via `statement_timeout_is_within_acceptable_bounds`/`lock_timeout_is_within_acceptable_bounds`) and `Nandi::Validation::TimeoutValidator` (via the timeout policies above) now call `migration.database_name`.

In `spec/nandi/validator_spec.rb`, find:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout,
                    strictest_lock: strictest_lock)
  end
```

Replace with:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout,
                    strictest_lock: strictest_lock,
                    database_name: nil)
  end
```

In `spec/nandi/validation/timeout_validator_spec.rb`, find:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout)
  end
```

Replace with:

```ruby
  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout,
                    database_name: nil)
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/nandi/timeout_policies/access_exclusive_spec.rb spec/nandi/validator_spec.rb spec/nandi/validation/timeout_validator_spec.rb`
Expected: PASS, all examples across all three files green.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/timeout_policies/access_exclusive.rb lib/nandi/timeout_policies/concurrent.rb lib/nandi/validator.rb spec/nandi/timeout_policies/access_exclusive_spec.rb spec/nandi/validator_spec.rb spec/nandi/validation/timeout_validator_spec.rb
git commit -m "fix: resolve timeout policy and validator bounds per-database"
```

---

### Task 6: Add `concurrently:` override to `remove_index`

**Files:**
- Modify: `lib/nandi/instructions/remove_index.rb`
- Modify: `lib/nandi/migration.rb:150-152`
- Test: `spec/nandi/instructions/remove_index_spec.rb`
- Test: `spec/nandi/migration_spec.rb` (extend `describe "#remove_index"`, lines 100-152)
- Test: `spec/nandi/validation/timeout_validator_spec.rb` (extend the "removing an index" context, lines 93-131)

**Interfaces:**
- Consumes: `Migration#database_name` (Task 2), `Nandi.config.remove_index_concurrently(database_name)` (Task 1).
- Produces: `Instructions::RemoveIndex#initialize(table:, field:, concurrently: true)`, `#concurrent?` (Boolean) — consumed by Task 7. `Migration#remove_index(table, target, concurrently: nil)`.

- [ ] **Step 1: Write the failing tests**

Rewrite `spec/nandi/instructions/remove_index_spec.rb` in full:

```ruby
# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/remove_index"
require "nandi/migration"

RSpec.describe Nandi::Instructions::RemoveIndex do
  let(:instance) { described_class.new(table: table, field: field, concurrently: concurrently) }
  let(:table) { :widgets }
  let(:field) { :foo }
  let(:concurrently) { true }

  describe "#table" do
    let(:table) { :thingumyjiggers }

    it "exposes the initial value" do
      expect(instance.table).to eq(:thingumyjiggers)
    end
  end

  describe "#extra_args" do
    subject(:args) { instance.extra_args }

    context "with a field" do
      it { is_expected.to eq(column: :foo, algorithm: :concurrently) }
    end

    context "with an array of fields" do
      let(:field) { %i[foo bar] }

      it { is_expected.to eq(column: %i[foo bar], algorithm: :concurrently) }
    end

    context "with a hash of arguments" do
      let(:field) { { name: :my_useless_index } }

      it "adds the algorithm: :concurrently setting" do
        expect(args).to eq(
          name: :my_useless_index,
          algorithm: :concurrently,
        )
      end
    end

    context "when concurrently is false" do
      let(:concurrently) { false }

      it "omits the algorithm key" do
        expect(args).to eq(column: :foo)
      end

      context "with a hash of arguments" do
        let(:field) { { name: :my_useless_index } }

        it "omits the algorithm key" do
          expect(args).to eq(name: :my_useless_index)
        end
      end
    end
  end

  describe "#lock" do
    context "when concurrently is true" do
      it "is SHARE" do
        expect(instance.lock).to eq(Nandi::Migration::LockWeights::SHARE)
      end
    end

    context "when concurrently is false" do
      let(:concurrently) { false }

      it "is ACCESS_EXCLUSIVE" do
        expect(instance.lock).to eq(Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE)
      end
    end
  end

  describe "#concurrent?" do
    context "when concurrently is true" do
      it { expect(instance.concurrent?).to be(true) }
    end

    context "when concurrently is false" do
      let(:concurrently) { false }

      it { expect(instance.concurrent?).to be(false) }
    end
  end

  describe "default concurrently value" do
    subject(:instance) { described_class.new(table: table, field: field) }

    it "defaults to true" do
      expect(instance.concurrent?).to be(true)
    end
  end
end
```

Add to `spec/nandi/migration_spec.rb`, inside `describe "#remove_index"` (after the existing "dropping an index by options hash" context, before its closing `end` on line 151):

```ruby
    context "with concurrently: false" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end

          def down
            remove_index :payments, :foo, concurrently: false
          end
        end
      end

      it "does not add the algorithm: :concurrently option" do
        expect(instructions.first.extra_args).to eq(column: :foo)
      end

      it "is not concurrent" do
        expect(instructions.first.concurrent?).to be(false)
      end
    end

    context "with concurrently: true" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end

          def down
            remove_index :payments, :foo, concurrently: true
          end
        end
      end

      it "is concurrent" do
        expect(instructions.first.concurrent?).to be(true)
      end
    end

    context "when concurrently is not specified" do
      subject(:instructions) { subject_class.new(validator, database_name: :analytics).down_instructions }

      let(:subject_class) do
        Class.new(described_class) do
          def up; end

          def down
            remove_index :payments, :foo
          end
        end
      end

      before do
        Nandi.config.register_database(:analytics, remove_index_concurrently: false)
      end

      after do
        Nandi.instance_variable_set(:@config, nil)
      end

      it "resolves the config default for the migration's database" do
        expect(instructions.first.concurrent?).to be(false)
      end
    end
```

Also add a new context to `spec/nandi/validation/timeout_validator_spec.rb`, nested inside the existing `context "removing an index" do` block — insert it as a new sibling context right after that block's `let(:instructions)` declaration and before its `context "with timeouts disabled" do`. (This file was already touched once in Task 5 to add `database_name: nil` to the top-level `instance_double`; re-read the current file rather than trusting stale line numbers.) This confirms the "no changes needed" claim about `TimeoutPolicies.policy_for` by exercising a real, non-concurrent `RemoveIndex` end-to-end and checking it's validated against `access_exclusive_*` bounds instead of `concurrent_*` bounds:

```ruby
    context "when concurrently: false" do
      let(:instructions) do
        [
          Nandi::Instructions::RemoveIndex.new(
            table: :payments,
            field: :foo,
            concurrently: false,
          ),
        ]
      end

      context "with a statement timeout within access_exclusive bounds" do
        let(:statement_timeout) { 1500 }
        let(:lock_timeout) { 5000 }

        it { is_expected.to be_success }
      end

      context "with a statement timeout that exceeds access_exclusive bounds" do
        let(:statement_timeout) { 1501 }
        let(:lock_timeout) { 5000 }

        it { is_expected.to be_failure }
      end

      context "with timeouts disabled" do
        before do
          allow(migration).to receive_messages(disable_statement_timeout?: true, disable_lock_timeout?: true)
        end

        it "is still a failure, unlike a concurrent remove_index" do
          is_expected.to be_failure
        end
      end
    end
```

Note: `allow(Nandi.config).to receive(:access_exclusive_statement_timeout_max).and_return(1500)` and `allow(Nandi.config).to receive(:access_exclusive_lock_timeout_max).and_return(750)` are already stubbed with no argument matcher in this file's top-level `before` block, so they'll match the `migration.database_name` (`nil`) call these tests exercise via `AccessExclusive` — no further stubbing needed here. The `lock_timeout: 5000` above is deliberately above the stubbed `750` max but that's irrelevant to the "statement timeout" contexts since `is_expected.to be_success` additionally requires the lock timeout to pass; adjust `lock_timeout` to `750` in the "within access_exclusive bounds" context if the test fails on the lock timeout assertion instead of the statement timeout one being tested (see Step 2).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/nandi/instructions/remove_index_spec.rb spec/nandi/migration_spec.rb spec/nandi/validation/timeout_validator_spec.rb -e "#remove_index"`
Expected: FAIL — `ArgumentError: unknown keyword: :concurrently` (both for `RemoveIndex.new(..., concurrently: ...)` and for `remove_index :payments, :foo, concurrently: false`), and `NoMethodError: undefined method 'concurrent?'`.

Run: `bundle exec rspec spec/nandi/validation/timeout_validator_spec.rb -e "when concurrently: false"`
Expected: FAIL for the same `ArgumentError: unknown keyword: :concurrently` reason. Once Step 3 lands, re-check the "within access_exclusive bounds" example specifically: if it fails because `lock_timeout` (5000) exceeds the stubbed `access_exclusive_lock_timeout_max` (750), lower `lock_timeout` in that context to `750` so both the statement and lock timeout assertions are satisfied together.

- [ ] **Step 3: Write the minimal implementation**

Replace `lib/nandi/instructions/remove_index.rb` in full:

```ruby
# frozen_string_literal: true

module Nandi
  module Instructions
    class RemoveIndex
      def initialize(table:, field:, concurrently: true)
        @table = table
        @field = field
        @concurrently = concurrently
      end

      def procedure
        :remove_index
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

      attr_reader :table

      private

      attr_reader :field, :concurrently

      def columns
        columns = Array(field)
        columns = columns.first if columns.one?

        columns
      end
    end
  end
end
```

In `lib/nandi/migration.rb`, replace:

```ruby
    def remove_index(table, target)
      current_instructions << Instructions::RemoveIndex.new(table: table, field: target)
    end
```

with:

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

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/nandi/instructions/remove_index_spec.rb spec/nandi/migration_spec.rb spec/nandi/validation/timeout_validator_spec.rb`
Expected: PASS, all examples in all three files green.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/instructions/remove_index.rb lib/nandi/migration.rb spec/nandi/instructions/remove_index_spec.rb spec/nandi/migration_spec.rb spec/nandi/validation/timeout_validator_spec.rb
git commit -m "feat: allow disabling CONCURRENTLY on a per-call basis for remove_index"
```

---

### Task 7: Fix `should_disable_ddl_transaction?` to use a `concurrent?` predicate

**Files:**
- Modify: `lib/nandi/instructions/add_index.rb:31-33`
- Modify: `lib/nandi/renderers/active_record/generate.rb:31-34`
- Test: `spec/nandi/instructions/add_index_spec.rb` (add `#concurrent?` coverage — create this file if it doesn't already exist; check first)
- Test: `spec/nandi/renderers/active_record_spec.rb` (new `describe "#remove_index"` block)
- Fixture: `spec/nandi/fixtures/rendered/active_record/create_and_drop_index_non_concurrent.rb` (new)

**Interfaces:**
- Consumes: `Instructions::RemoveIndex#concurrent?` (Task 6).
- Produces: `Instructions::AddIndex#concurrent?` (always `true`). `Generate#should_disable_ddl_transaction?` now checks `concurrent?` instead of matching on the procedure name string.

- [ ] **Step 1a: Check for an existing `add_index_spec.rb`**

Run: `ls spec/nandi/instructions/add_index_spec.rb`

If it exists, read it and add a `#concurrent?` test following its existing conventions. If it does not exist, skip adding an `AddIndex`-specific spec file — `#concurrent?` on `AddIndex` is already exercised indirectly by the fixture test in Step 1b below (through `should_disable_ddl_transaction?`), which is sufficient coverage for this one-line addition.

- [ ] **Step 1b: Write the failing test**

Add a new `describe` block to `spec/nandi/renderers/active_record_spec.rb`, right after the existing `describe "adding and dropping an index"` block closes (after line 78, before `describe "creating and dropping a table" do`):

```ruby
    describe "dropping an index without CONCURRENTLY" do
      let(:fixture) do
        normalize_fixture(File.read(File.join(fixture_root, "create_and_drop_index_non_concurrent.rb")))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_column :payments, :foo, :text
          end

          def down
            remove_index :payments, :foo, concurrently: false
          end
        end
      end

      it { is_expected.to eq(fixture) }

      it "does not disable the DDL transaction" do
        expect(migration).to_not include("disable_ddl_transaction!")
      end
    end
```

Create a placeholder fixture file so the first assertion has something to diff against (it will fail, and you'll replace its contents with the real output in Step 3):

```bash
touch spec/nandi/fixtures/rendered/active_record/create_and_drop_index_non_concurrent.rb
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/nandi/renderers/active_record_spec.rb -e "dropping an index without CONCURRENTLY"`
Expected: FAIL on the fixture-equality example (empty fixture file vs. actual rendered output) — RSpec's diff output will show the actual rendered migration text. The "does not disable the DDL transaction" example is expected to PASS already, since `remove_index` with `concurrently: false` no longer matches `procedure.to_s.include?("index")`... actually it will still match, since `:remove_index` includes `"index"` — confirm this example FAILS too (it should, demonstrating the bug this task fixes).

- [ ] **Step 3: Write the minimal implementation**

In `lib/nandi/instructions/add_index.rb`, add a `concurrent?` method next to `#lock` (after line 33):

```ruby
      def lock
        Nandi::Migration::LockWeights::SHARE
      end

      def concurrent?
        true
      end
```

In `lib/nandi/renderers/active_record/generate.rb`, replace:

```ruby
        def should_disable_ddl_transaction?
          [*up_instructions, *down_instructions].
            any? { |i| i.procedure.to_s.include?("index") }
        end
```

with:

```ruby
        def should_disable_ddl_transaction?
          [*up_instructions, *down_instructions].any? { |i| i.respond_to?(:concurrent?) && i.concurrent? }
        end
```

Now generate the real fixture content. Run:

```bash
bundle exec rspec spec/nandi/renderers/active_record_spec.rb -e "dropping an index without CONCURRENTLY" --format documentation
```

This will still fail on the fixture-equality example, but RSpec's failure diff shows the exact actual rendered string. Copy that actual output verbatim into `spec/nandi/fixtures/rendered/active_record/create_and_drop_index_non_concurrent.rb` (matching the whitespace/formatting conventions already visible in `spec/nandi/fixtures/rendered/active_record/create_and_drop_column.rb`, since this migration also uses default access-exclusive timeouts and therefore `set_lock_timeout(5000)` / `set_statement_timeout(1500)` rather than `disable_lock_timeout!`/`disable_statement_timeout!`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/nandi/renderers/active_record_spec.rb`
Expected: PASS, all examples in the file green, including both new examples.

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/instructions/add_index.rb lib/nandi/renderers/active_record/generate.rb spec/nandi/renderers/active_record_spec.rb spec/nandi/fixtures/rendered/active_record/create_and_drop_index_non_concurrent.rb
git commit -m "fix: disable DDL transaction based on instruction concurrency, not procedure name"
```

---

### Task 8: Update README documentation

**Files:**
- Modify: `README.md:150` (the `remove_index` narrative section)
- Modify: `README.md:556-568` (the `register_database` options list)

**Interfaces:** None — documentation only.

- [ ] **Step 1: Update the `remove_index` narrative**

In `README.md`, find the paragraph right after the fenced code block ending at line 148 (the `add_index`/`remove_index` example):

```
Nandi has added in the `algorithm: :concurrently` option, ensuring that the index is not built immediately with the table locked in the meantime (a common source of pain). You can't use that option within a transaction, however, so Nandi uses the `disable_ddl_transaction!` macro. And we're ready to go.
```

Replace with:

```
Nandi has added in the `algorithm: :concurrently` option, ensuring that the index is not built immediately with the table locked in the meantime (a common source of pain). You can't use that option within a transaction, however, so Nandi uses the `disable_ddl_transaction!` macro. And we're ready to go.

`remove_index` accepts an optional `concurrently:` keyword argument to opt out of `CONCURRENTLY` for a single call, regardless of the configured default:

```rb
def down
  remove_index :widgets, :name, concurrently: false
end
```

When `concurrently` is `false`, Nandi models the operation as taking a brief `ACCESS EXCLUSIVE` lock (like any other DDL statement) rather than a `SHARE` lock, so it's validated against the same tight `access_exclusive_*` timeouts as `add_column`, `remove_column`, etc., and can run inside a DDL transaction alongside other statements. The default for calls that don't specify `concurrently:` is controlled by the per-database `remove_index_concurrently` config option (default: `true`).
```

- [ ] **Step 2: Update the `register_database` options list**

In `README.md`, find the bullet list starting at line 559 and ending at line 568:

```
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
```

Add a new bullet at the end of this list (leave the existing lines, including the pre-existing `_limit`-named keys, untouched — renaming them is out of scope for this change):

```
- `remove_index_concurrently`: Whether `remove_index` uses `CONCURRENTLY` by default for this database; can still be overridden per-call via `remove_index(table, target, concurrently: ...)` (default: `true`)
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document remove_index concurrently option and remove_index_concurrently config"
```

---

### Task 9: Full regression check

**Files:** None modified — verification only.

- [ ] **Step 1: Run the full test suite**

Run: `bundle exec rspec`
Expected: PASS, 0 failures. The example count will be higher than the original baseline of 416 (this plan adds new examples in Tasks 1, 2, 3, 4, 5, 6, and 7).

- [ ] **Step 2: Run rubocop on all changed files**

Run: `bundle exec rubocop lib/nandi/multi_database.rb lib/nandi/config.rb lib/nandi/migration.rb lib/nandi/compiled_migration.rb lib/nandi/timeout_policies/access_exclusive.rb lib/nandi/timeout_policies/concurrent.rb lib/nandi/validator.rb lib/nandi/instructions/remove_index.rb lib/nandi/instructions/add_index.rb lib/nandi/renderers/active_record/generate.rb spec/nandi/multi_database_spec.rb spec/nandi/migration_spec.rb spec/nandi/compiled_migration_spec.rb spec/nandi/timeout_policies/access_exclusive_spec.rb spec/nandi/validator_spec.rb spec/nandi/validation/timeout_validator_spec.rb spec/nandi/instructions/remove_index_spec.rb spec/nandi/renderers/active_record_spec.rb`

Expected: no offenses. Fix any style violations reported (matching the style already present in each file) and re-run until clean.

- [ ] **Step 3: Confirm no leftover debug artifacts**

Run: `git status`
Expected: only the files modified across Tasks 1-8 are changed; no stray temp files (e.g. leftover `touch`ed empty fixtures from Task 7 if that task's Step 3 was skipped).
