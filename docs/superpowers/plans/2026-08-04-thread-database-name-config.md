# Thread database_name through Migration/Validator/TimeoutPolicies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Migration` aware of which database it's being compiled for, and thread that `database_name` into every existing per-database `Nandi.config` timeout lookup, so timeout config resolves against the correct database instead of always the default one.

**Architecture:** `CompiledMigration` already knows `db_name`. Add a `database_name` kwarg to `Migration#initialize` (default `nil`, matching every `Nandi.config` lookup method's own default), have `CompiledMigration#migration` pass it through, and have `Migration`'s private timeout-resolution methods and `TimeoutPolicies::AccessExclusive`/`Concurrent` pass `database_name` into their `Nandi.config` calls.

**Tech Stack:** Ruby, RSpec.

## Global Constraints

- `database_name: nil` must be the default at every layer — `Nandi.config`'s lookup methods already treat `nil` as "use the default database," so this keeps all 50+ existing `Migration.new(validator)` call sites (in `spec/nandi/migration_spec.rb`) and the one production call site (in `CompiledMigration`) working unmodified once updated.
- Do NOT touch `Nandi::Migration#remove_index` or add a `concurrently:` parameter — that feature is unrelated and out of scope (it's why the original PR #156 was closed).
- Do NOT modify `Validator#statement_timeout_is_within_acceptable_bounds` / `#lock_timeout_is_within_acceptable_bounds` (`lib/nandi/validator.rb`) — they are dead code (no callers); leave them as-is.
- Do NOT add `database_name` to `Nandi::Validation::EachValidator` or any instruction-level validator — that's separate follow-up work on a different branch.

---

### Task 1: Add `database_name` to `Nandi::Migration`

**Files:**
- Modify: `lib/nandi/migration.rb:72-76` (initialize), `lib/nandi/migration.rb:340-354` (`disable_lock_timeout?`, `disable_statement_timeout?`), `lib/nandi/migration.rb:386-400` (`default_statement_timeout`, `default_lock_timeout`)
- Test: `spec/nandi/migration_spec.rb`

**Interfaces:**
- Consumes: `Nandi.config.concurrent_lock_timeout(database_name = nil)`, `Nandi.config.concurrent_statement_timeout(database_name = nil)`, `Nandi.config.access_exclusive_statement_timeout(database_name = nil)`, `Nandi.config.access_exclusive_lock_timeout(database_name = nil)` — all already exist in `lib/nandi/config.rb`.
- Produces: `Migration#initialize(validator, database_name: nil)` and `Migration#database_name` (public reader, returns the raw value passed in, `nil` by default). Task 2 and Task 3 both call `migration.database_name`.

- [ ] **Step 1: Write the failing tests**

Open `spec/nandi/migration_spec.rb`. Insert a new top-level `describe "#database_name" do` block immediately after the closing `end` of the `describe "name" do` block (after line 18, before `describe "#up and #down" do` on line 20):

```ruby
  describe "#database_name" do
    context "when not specified" do
      subject(:migration) { subject_class.new(validator) }

      let(:subject_class) do
        Class.new(described_class) do
          def up; end
        end
      end

      it "defaults to nil" do
        expect(migration.database_name).to be_nil
      end
    end

    context "when specified" do
      subject(:migration) { subject_class.new(validator, database_name: :analytics) }

      let(:subject_class) do
        Class.new(described_class) do
          def up; end
        end
      end

      it "returns the given database name" do
        expect(migration.database_name).to eq(:analytics)
      end
    end
  end

```

Next, find the `describe "timeouts" do` block. Inside it, immediately before the final `end` that closes the `describe "timeouts" do` block (the `end` on the line right before the outer `RSpec.describe` block's closing `end`), add this new context:

```ruby
    context "with an explicit database_name" do
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
        allow(Nandi.config).to receive(:concurrent_lock_timeout).with(:analytics).and_return(120_000)
        allow(Nandi.config).to receive(:concurrent_statement_timeout).with(:analytics).and_return(600_000)
      end

      it "resolves disable_lock_timeout? and disable_statement_timeout? for that database" do
        expect(migration.disable_lock_timeout?).to be(false)
        expect(migration.disable_statement_timeout?).to be(false)
      end

      it "resolves lock_timeout and statement_timeout for that database" do
        expect(migration.lock_timeout).to eq(120_000)
        expect(migration.statement_timeout).to eq(600_000)
      end
    end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/nandi/migration_spec.rb`
Expected: FAIL — `#database_name` tests fail with `NoMethodError: undefined method 'database_name'`; the `"with an explicit database_name"` tests fail with `ArgumentError: unknown keyword: :database_name`.

- [ ] **Step 3: Implement `database_name` on `Migration`**

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

Then replace:

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

Then replace:

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/nandi/migration_spec.rb`
Expected: PASS (all examples, including the new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/migration.rb spec/nandi/migration_spec.rb
git commit -m "Add database_name to Migration for per-database config resolution"
```

---

### Task 2: Thread `database_name` from `CompiledMigration` into `Migration`

**Files:**
- Modify: `lib/nandi/compiled_migration.rb:52-54`
- Test: `spec/nandi/compiled_migration_spec.rb`

**Interfaces:**
- Consumes: `Migration#initialize(validator, database_name: nil)` from Task 1. `CompiledMigration#db_name` (existing, returns `@db_config.name`, already resolves `nil` input to the default database's name — see `spec/nandi/compiled_migration_spec.rb:125-138`).
- Produces: `CompiledMigration#migration` now returns a `Migration` instance whose `#database_name` equals `db_name`.

- [ ] **Step 1: Write the failing tests**

Open `spec/nandi/compiled_migration_spec.rb`. Insert a new `describe "#migration" do` block immediately after the `describe "#source_digest" do` block ends (after line 123, before `describe "nil db_name handling" do` on line 125):

```ruby
  describe "#migration" do
    subject(:migration) { compiled_migration.migration }

    context "when db_name is nil" do
      let(:db_name) { nil }

      it "passes the resolved default database_name to Migration" do
        expect(migration.database_name).to eq(:primary)
      end
    end

    context "when db_name is explicitly provided" do
      before do
        Nandi.config.register_database(:analytics,
                                       migration_directory: base_path,
                                       output_directory: "db/analytics_migrate")
      end

      let(:db_name) { :analytics }

      it "passes the database_name to Migration" do
        expect(migration.database_name).to eq(:analytics)
      end
    end
  end

```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/nandi/compiled_migration_spec.rb`
Expected: FAIL — both new examples fail with an equality mismatch (`expected: :primary`/`:analytics`, `got: nil`), since `Migration#database_name` isn't being set yet.

- [ ] **Step 3: Implement the change**

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/nandi/compiled_migration_spec.rb`
Expected: PASS (all examples, including the new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/nandi/compiled_migration.rb spec/nandi/compiled_migration_spec.rb
git commit -m "Pass database_name from CompiledMigration to Migration"
```

---

### Task 3: Thread `migration.database_name` into `TimeoutPolicies::AccessExclusive` and `Concurrent`

**Files:**
- Modify: `lib/nandi/timeout_policies/access_exclusive.rb:45-51`
- Modify: `lib/nandi/timeout_policies/concurrent.rb:55-61`
- Test: `spec/nandi/timeout_policies/access_exclusive_spec.rb`
- Test: Create `spec/nandi/timeout_policies/concurrent_spec.rb`

**Interfaces:**
- Consumes: `Migration#database_name` from Task 1 (accessed via the `migration` object each policy already holds).
- Produces: `TimeoutPolicies::AccessExclusive#statement_timeout_maximum`/`#lock_timeout_maximum` and `TimeoutPolicies::Concurrent#minimum_lock_timeout`/`#minimum_statement_timeout` now resolve against `migration.database_name` instead of the default database.

- [ ] **Step 1: Write the failing tests for `AccessExclusive`**

Open `spec/nandi/timeout_policies/access_exclusive_spec.rb`. Replace the `let(:migration)` block:

```ruby
    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout)
    end
```

with:

```ruby
    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout,
                      database_name: database_name)
    end

    let(:database_name) { nil }
```

Then, immediately before the final `end` that closes the `describe "::validate" do` block (right before line 98's `end`), add:

```ruby
    context "with a migration for a specific database" do
      let(:database_name) { :analytics }
      let(:statement_timeout) { 1499 }
      let(:lock_timeout) { 749 }

      before do
        allow(Nandi.config).to receive(:access_exclusive_statement_timeout_max).
          with(:analytics).and_return(1500)
        allow(Nandi.config).to receive(:access_exclusive_lock_timeout_max).
          with(:analytics).and_return(750)
      end

      it { is_expected.to be_success }

      it "resolves timeouts using the migration's database_name" do
        validate
        expect(Nandi.config).to have_received(:access_exclusive_statement_timeout_max).with(:analytics)
        expect(Nandi.config).to have_received(:access_exclusive_lock_timeout_max).with(:analytics)
      end
    end
```

- [ ] **Step 2: Run the `AccessExclusive` tests to verify the new ones fail**

Run: `bundle exec rspec spec/nandi/timeout_policies/access_exclusive_spec.rb`
Expected: The pre-existing examples still PASS (the `database_name: nil` stub satisfies the currently-argument-less `Nandi.config` calls). The two new examples in `"with a migration for a specific database"` FAIL: the `have_received(...).with(:analytics)` expectations fail because the production code doesn't pass any argument yet.

- [ ] **Step 3: Implement the `AccessExclusive` change**

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

- [ ] **Step 4: Run the `AccessExclusive` tests to verify they pass**

Run: `bundle exec rspec spec/nandi/timeout_policies/access_exclusive_spec.rb`
Expected: PASS (all examples)

- [ ] **Step 5: Write the failing tests for `Concurrent` (new spec file)**

There is currently no spec file for `Nandi::TimeoutPolicies::Concurrent`. Create `spec/nandi/timeout_policies/concurrent_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/timeout_policies"
require "nandi/timeout_policies/concurrent"

RSpec.describe Nandi::TimeoutPolicies::Concurrent do
  describe "::validate" do
    subject(:validate) { described_class.validate(migration) }

    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout,
                      database_name: database_name)
    end

    let(:database_name) { nil }

    before do
      allow(migration).to receive_messages(disable_statement_timeout?: false, disable_lock_timeout?: false)
      allow(Nandi.config).to receive_messages(concurrent_statement_timeout_min: 30_000,
                                              concurrent_lock_timeout_min: 10_000)
    end

    context "with valid timeouts" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 10_000 }

      it { is_expected.to be_success }
    end

    context "with too-low statement timeout" do
      let(:statement_timeout) { 29_999 }
      let(:lock_timeout) { 10_000 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "statement timeout for concurrent operations must be at least 30000",
          ])
      end
    end

    context "with disabled statement timeout" do
      let(:statement_timeout) { 29_999 }
      let(:lock_timeout) { 10_000 }

      before do
        allow(migration).to receive(:disable_statement_timeout?).and_return(true)
      end

      it { is_expected.to be_success }
    end

    context "with too-low lock timeout" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 9_999 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "lock timeout for concurrent operations must be at least 10000",
          ])
      end
    end

    context "with disabled lock timeout" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 9_999 }

      before do
        allow(migration).to receive(:disable_lock_timeout?).and_return(true)
      end

      it { is_expected.to be_success }
    end

    context "with a migration for a specific database" do
      let(:database_name) { :analytics }
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 10_000 }

      before do
        allow(Nandi.config).to receive(:concurrent_statement_timeout_min).
          with(:analytics).and_return(30_000)
        allow(Nandi.config).to receive(:concurrent_lock_timeout_min).
          with(:analytics).and_return(10_000)
      end

      it { is_expected.to be_success }

      it "resolves timeouts using the migration's database_name" do
        validate
        expect(Nandi.config).to have_received(:concurrent_statement_timeout_min).with(:analytics)
        expect(Nandi.config).to have_received(:concurrent_lock_timeout_min).with(:analytics)
      end
    end
  end
end
```

- [ ] **Step 6: Run the `Concurrent` tests to verify the database-specific ones fail**

Run: `bundle exec rspec spec/nandi/timeout_policies/concurrent_spec.rb`
Expected: The general examples PASS (production code already works correctly for the default database). The `"with a migration for a specific database"` examples FAIL: the `have_received(...).with(:analytics)` expectations fail because the production code doesn't pass any argument yet.

- [ ] **Step 7: Implement the `Concurrent` change**

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

- [ ] **Step 8: Run both timeout policy spec files to verify everything passes**

Run: `bundle exec rspec spec/nandi/timeout_policies/access_exclusive_spec.rb spec/nandi/timeout_policies/concurrent_spec.rb`
Expected: PASS (all examples)

- [ ] **Step 9: Run the full test suite**

Run: `bundle exec rspec`
Expected: PASS (0 failures) — this confirms no regressions across the rest of the suite (in particular `spec/nandi/validator_spec.rb`, `spec/nandi/migration_spec.rb`, and `spec/nandi/compiled_migration_spec.rb`).

- [ ] **Step 10: Commit**

```bash
git add lib/nandi/timeout_policies/access_exclusive.rb lib/nandi/timeout_policies/concurrent.rb \
  spec/nandi/timeout_policies/access_exclusive_spec.rb spec/nandi/timeout_policies/concurrent_spec.rb
git commit -m "Resolve timeout policy bounds against the migration's database_name"
```
