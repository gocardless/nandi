# frozen_string_literal: true

require "nandi/safe_migration_enforcer"

RSpec.shared_examples "linting" do
  let(:db_name) { nil } # Test default single-database behavior

  context "when there are no files" do
    let(:safe_migrations) { [] }
    let(:ar_migrations) { [] }

    it "returns true" do
      expect(subject.run).to eq(true)
    end
  end

  context "when all safe migrations and generated ActiveRecord migrations match" do
    it "returns true" do
      expect(subject.run).to eq(true)
    end
  end

  context "when a generated ActiveRecord migration is missing" do
    before do
      ar_migrations.shift
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error(
        Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        /pending generation.*20190513163422_add_elephants.rb/m,
      )
    end
  end

  context "when an ActiveRecord migration has been written rather than generated" do
    before do
      safe_migrations.shift
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error(
        Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        /20190513163422_add_elephants.rb.*Please use Nandi/m,
      )
    end
  end

  context "when a safe migration has had its content altered" do
    let(:altered_migration) { safe_migrations.first }

    before do
      allow(File).to receive(:read).with(kind_of(String)).
        and_return("generated_content")
      allow(File).to receive(:read).
        with(Regexp.new("#{safe_migration_dir}/#{altered_migration}")).
        and_return("newer_content")
      allow(File).to receive(:read).with(Nandi.config.lockfile_path(db_name)).and_return(lockfile)
      allow(File).to receive(:write).with(Nandi.config.lockfile_path(db_name), kind_of(String)).
        and_return(lockfile)
    end

    # rubocop:disable RSpec/ExampleLength
    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error do |err|
        expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
        expect(err.message).
          to match(
            /20190513163422_add_elephants.rb.*Please recompile your migrations/m,
          )
        expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end

  context "when a generated migration has had its content altered" do
    let(:altered_migration) { ar_migrations.first }

    before do
      allow(File).to receive(:read).with(kind_of(String)).
        and_return("generated_content")
      allow(File).to receive(:read).
        with(Regexp.new("#{ar_migration_dir}/#{altered_migration}")).
        and_return("hand_edited_content")
      allow(File).to receive(:read).with(Nandi.config.lockfile_path(db_name)).and_return(lockfile)
      allow(File).to receive(:write).with(Nandi.config.lockfile_path(db_name), kind_of(String)).
        and_return(lockfile)
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error do |err|
        expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
        expect(err.message).
          to match(/20190513163422_add_elephants.rb.*Please don't hand-edit/m)
        expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
      end
    end
  end
end

RSpec.describe Nandi::SafeMigrationEnforcer do
  subject { described_class.new }

  let(:safe_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_SAFE_MIGRATION_DIR }
  let(:ar_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_AR_MIGRATION_DIR }

  let(:safe_migrations) do
    [
      "20190513163422_add_elephants.rb",
      "20190513163423_add_beachballs.rb",
      "20190513163424_add_zoos.rb",
    ]
  end
  let(:ar_migrations) do
    [
      "20190513163422_add_elephants.rb",
      "20190513163423_add_beachballs.rb",
      "20190513163424_add_zoos.rb",
    ]
  end

  let(:ar_migration_paths) { ar_migrations.map { |f| File.join(ar_migration_dir, f) } }

  let(:lockfile) do
    lockfile_contents = ar_migration_paths.each_with_object({}) do |ar_file, hash|
      file_name = File.basename(ar_file)

      hash[file_name] = {
        source_digest: Digest::SHA256.hexdigest("generated_content"),
        compiled_digest: Digest::SHA256.hexdigest("generated_content"),
      }
    end

    lockfile_contents.with_indifferent_access
  end

  before do
    allow_any_instance_of(described_class).
      to receive(:matching_migrations).
      with(safe_migration_dir).
      and_return(safe_migrations)

    allow_any_instance_of(described_class).
      to receive(:matching_migrations).
      with(ar_migration_dir).
      and_return(ar_migrations)

    # Test default single-database behavior - mock lockfile instance methods
    allow_any_instance_of(Nandi::Lockfile).to receive(:get) do |_instance, file_name|
      if lockfile.key?(file_name)
        lockfile.fetch(file_name)
      else
        { source_digest: nil, compiled_digest: nil }
      end
    end

    allow(File).to receive(:read).with(Regexp.new(safe_migration_dir)).
      and_return("generated_content")

    allow(File).to receive(:read).with(Regexp.new(ar_migration_dir)).
      and_return("generated_content")
  end

  describe "#run" do
    context "with the default migration directories" do
      it_behaves_like "linting"
    end

    context "with custom migration directories" do
      subject do
        described_class.new(
          safe_migration_dir: safe_migration_dir,
          ar_migration_dir: ar_migration_dir,
        )
      end

      let(:safe_migration_dir) { "custom/safe/migration/dir" }
      let(:ar_migration_dir) { "custom/ar/migration/dir" }

      it_behaves_like "linting"
    end
  end

  describe "multi-database support" do
    subject(:enforcer) { described_class.new }

    let(:temp_dir) { "/tmp/nandi_test" }
    let(:primary_migrations) { ["20240101000000_primary_migration.rb"] }
    let(:analytics_migrations) { ["20240102000000_analytics_migration.rb"] }

    before do
      # Reset Nandi configuration
      Nandi.instance_variable_set(:@config, nil)

      # Configure multi-database setup
      Nandi.configure do |config|
        config.lockfile_directory = temp_dir
        config.register_database(
          :primary,
          migration_directory: "#{temp_dir}/db/safe_migrations",
          output_directory: "#{temp_dir}/db/migrate",
        )
        config.register_database(
          :analytics,
          migration_directory: "#{temp_dir}/db/analytics_safe_migrations",
          output_directory: "#{temp_dir}/db/analytics_migrate",
        )
      end

      # Mock directory existence
      allow(Dir).to receive(:exist?).and_return(true)

      # Mock migration file discovery for primary database
      allow_any_instance_of(described_class).to receive(:matching_migrations).
        with("#{temp_dir}/db/safe_migrations").and_return(primary_migrations)
      allow_any_instance_of(described_class).to receive(:matching_migrations).
        with("#{temp_dir}/db/migrate").and_return(primary_migrations)

      # Mock migration file discovery for analytics database
      allow_any_instance_of(described_class).to receive(:matching_migrations).
        with("#{temp_dir}/db/analytics_safe_migrations").and_return(analytics_migrations)
      allow_any_instance_of(described_class).to receive(:matching_migrations).
        with("#{temp_dir}/db/analytics_migrate").and_return(analytics_migrations)

      # Mock lockfile instances for each database
      primary_lockfile = instance_double(Nandi::Lockfile)
      analytics_lockfile = instance_double(Nandi::Lockfile)

      allow(Nandi::Lockfile).to receive(:for).with(:primary).and_return(primary_lockfile)
      allow(Nandi::Lockfile).to receive(:for).with(:analytics).and_return(analytics_lockfile)

      # Mock lockfile data
      allow(primary_lockfile).to receive(:get) do |filename|
        if filename == "20240101000000_primary_migration.rb"
          { source_digest: "primary_source", compiled_digest: "primary_compiled" }
        else
          { source_digest: nil, compiled_digest: nil }
        end
      end

      allow(analytics_lockfile).to receive(:get) do |filename|
        if filename == "20240102000000_analytics_migration.rb"
          { source_digest: "analytics_source", compiled_digest: "analytics_compiled" }
        else
          { source_digest: nil, compiled_digest: nil }
        end
      end

      # Mock file reading for FileDiff to return unchanged content by default
      allow(File).to receive(:read).and_return("migration_content")

      # Mock FileDiff to return false (no changes) by default
      allow_any_instance_of(Nandi::FileDiff).to receive(:changed?).and_return(false)
    end

    after do
      # Reset Nandi configuration after each test
      Nandi.instance_variable_set(:@config, nil)
    end

    context "when all databases are properly configured" do
      it "validates all databases successfully" do
        expect(enforcer.run).to eq(true)
      end
    end

    context "when there are ungenerated migrations in multiple databases" do
      before do
        # Remove AR migrations to simulate ungenerated state
        allow_any_instance_of(described_class).to receive(:matching_migrations).
          with("#{temp_dir}/db/migrate").and_return([])
        allow_any_instance_of(described_class).to receive(:matching_migrations).
          with("#{temp_dir}/db/analytics_migrate").and_return([])
      end

      # rubocop:disable RSpec/ExampleLength
      it "reports violations from all databases with full paths" do
        expect { enforcer.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        ) do |error|
          expect(error.message).to include("#{temp_dir}/db/safe_migrations/20240101000000_primary_migration.rb")
          expect(error.message).to include(
            "#{temp_dir}/db/analytics_safe_migrations/20240102000000_analytics_migration.rb",
          )
          expect(error.message).to include("pending generation")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when there are handwritten migrations in multiple databases" do
      before do
        # Remove safe migrations to simulate handwritten state
        allow_any_instance_of(described_class).to receive(:matching_migrations).
          with("#{temp_dir}/db/safe_migrations").and_return([])
        allow_any_instance_of(described_class).to receive(:matching_migrations).
          with("#{temp_dir}/db/analytics_safe_migrations").and_return([])
      end

      # rubocop:disable RSpec/ExampleLength
      it "reports violations from all databases with full paths" do
        expect { enforcer.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        ) do |error|
          expect(error.message).to include("#{temp_dir}/db/migrate/20240101000000_primary_migration.rb")
          expect(error.message).to include("#{temp_dir}/db/analytics_migrate/20240102000000_analytics_migration.rb")
          expect(error.message).to include("written by hand")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when there are out of date migrations" do
      before do
        # Mock FileDiff to return true (changed) only for safe migrations directory
        allow_any_instance_of(Nandi::FileDiff).to receive(:changed?) do |instance|
          file_path = instance.instance_variable_get(:@file_path)
          file_path.include?("safe_migrations") && file_path.include?("20240101000000_primary_migration.rb")
        end
      end

      # rubocop:disable RSpec/ExampleLength
      it "reports out of date migrations with full paths" do
        expect { enforcer.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        ) do |error|
          expect(error.message).to include("#{temp_dir}/db/safe_migrations/20240101000000_primary_migration.rb")
          expect(error.message).to include("changed but not been recompiled")
          expect(error.message).to_not include("analytics_migration")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when there are hand edited migrations" do
      before do
        # Mock FileDiff to return true (changed) for specific output migrations
        allow_any_instance_of(Nandi::FileDiff).to receive(:changed?) do |instance|
          instance.instance_variable_get(:@file_path).include?("analytics_migrate")
        end
      end

      # rubocop:disable RSpec/ExampleLength
      it "reports hand edited migrations with full paths" do
        expect { enforcer.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        ) do |error|
          expect(error.message).to include("#{temp_dir}/db/analytics_migrate/20240102000000_analytics_migration.rb")
          expect(error.message).to include("generated content altered")
          expect(error.message).to_not include("primary_migration")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when there are violations in only one database" do
      before do
        # Only primary database has missing migration
        allow_any_instance_of(described_class).to receive(:matching_migrations).
          with("#{temp_dir}/db/migrate").and_return([])
      end

      it "reports violations from the affected database only" do
        expect { enforcer.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        ) do |error|
          expect(error.message).to include("20240101000000_primary_migration.rb")
          expect(error.message).to_not include("20240102000000_analytics_migration.rb")
        end
      end
    end
  end
end
