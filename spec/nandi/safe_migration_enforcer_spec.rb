# frozen_string_literal: true

require "nandi/safe_migration_enforcer"

RSpec.shared_examples "linting behavior" do

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
    end

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
  end

  context "when a generated migration has had its content altered" do
    let(:altered_migration) { ar_migrations.first }

    before do
      allow(File).to receive(:read).with(kind_of(String)).
        and_return("generated_content")
      allow(File).to receive(:read).
        with(Regexp.new("#{ar_migration_dir}/#{altered_migration}")).
        and_return("hand_edited_content")
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

RSpec.shared_context "single database enforcer setup" do
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
    allow_any_instance_of(Nandi::Lockfile).to receive(:get) do |_instance, file_name:|
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
end

RSpec.describe Nandi::SafeMigrationEnforcer do
  describe "single database mode behavior" do
    describe "#run" do
      context "with default migration directories" do
        subject { described_class.new }

        let(:db_name) { nil }
        let(:safe_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_SAFE_MIGRATION_DIR }
        let(:ar_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_AR_MIGRATION_DIR }

        include_context "single database enforcer setup"
        include_examples "linting behavior"
      end

      context "with custom migration directories" do
        subject do
          described_class.new(
            safe_migration_dir: safe_migration_dir,
            ar_migration_dir: ar_migration_dir,
          )
        end

        let(:db_name) { nil }
        let(:safe_migration_dir) { "custom/safe/migration/dir" }
        let(:ar_migration_dir) { "custom/ar/migration/dir" }

        include_context "single database enforcer setup"
        include_examples "linting behavior"
      end
    end
  end

  describe "multi-database support" do
    subject { described_class.new }

    let(:temp_dir) { "/tmp/nandi_test" }
    let(:primary_migrations) { ["20240101000000_primary_migration.rb"] }
    let(:analytics_migrations) { ["20240102000000_analytics_migration.rb"] }

    let(:lockfile) do
      {
        "20240101000000_primary_migration.rb" => {
          source_digest: "primary_source",
          compiled_digest: "primary_compiled"
        },
        "20240102000000_analytics_migration.rb" => {
          source_digest: "analytics_source",
          compiled_digest: "analytics_compiled"
        }
      }
    end

    before do
      # Reset Nandi configuration
      Nandi.instance_variable_set(:@config, nil)

      # Configure multi-database setup
      Nandi.configure do |config|
        config.lockfile_directory = temp_dir
        config.register_database(
          :primary,
          migration_directory: "#{temp_dir}/db/safe_migrations",
          output_directory: "#{temp_dir}/db/migrate"
        )
        config.register_database(
          :analytics,
          migration_directory: "#{temp_dir}/db/analytics_safe_migrations",
          output_directory: "#{temp_dir}/db/analytics_migrate"
        )
      end

      # Mock directory existence
      allow(Dir).to receive(:exist?).and_return(true)

      # Mock migration file discovery
      allow(Dir).to receive(:glob).with("#{temp_dir}/db/safe_migrations/*.rb").and_return(
        primary_migrations.map { |f| "#{temp_dir}/db/safe_migrations/#{f}" }
      )
      allow(Dir).to receive(:glob).with("#{temp_dir}/db/migrate/*.rb").and_return(
        primary_migrations.map { |f| "#{temp_dir}/db/migrate/#{f}" }
      )
      allow(Dir).to receive(:glob).with("#{temp_dir}/db/analytics_safe_migrations/*.rb").and_return(
        analytics_migrations.map { |f| "#{temp_dir}/db/analytics_safe_migrations/#{f}" }
      )
      allow(Dir).to receive(:glob).with("#{temp_dir}/db/analytics_migrate/*.rb").and_return(
        analytics_migrations.map { |f| "#{temp_dir}/db/analytics_migrate/#{f}" }
      )

      # Mock FileMatcher to return files as-is
      allow(Nandi::FileMatcher).to receive(:call) do |args|
        args[:files]
      end

      # Mock file reading for digest checking to match expected digests
      allow(File).to receive(:read).and_return("migration_content")

      # Mock FileDiff to return false (no changes) by default
      allow_any_instance_of(Nandi::FileDiff).to receive(:changed?).and_return(false)
    end

    after do
      # Reset Nandi configuration after each test to prevent interference
      Nandi.instance_variable_set(:@config, nil)
    end

    context "when all databases are properly configured" do
      it "validates all databases successfully" do
        expect(subject.run).to eq(true)
      end
    end

    context "when there are violations in multiple databases" do
      before do
        # Simulate missing migrations in both databases
        allow(Dir).to receive(:glob).with("#{temp_dir}/db/migrate/*.rb").and_return([])
        allow(Dir).to receive(:glob).with("#{temp_dir}/db/analytics_migrate/*.rb").and_return([])
      end

      it "reports violations from all databases" do
        expect { subject.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed
        ) do |error|
          expect(error.message).to include("20240101000000_primary_migration.rb")
          expect(error.message).to include("20240102000000_analytics_migration.rb")
        end
      end
    end

    context "when there are violations in only one database" do
      before do
        # Only primary database has missing migration
        allow(Dir).to receive(:glob).with("#{temp_dir}/db/migrate/*.rb").and_return([])
      end

      it "reports violations from the affected database only" do
        expect { subject.run }.to raise_error(
          Nandi::SafeMigrationEnforcer::MigrationLintingFailed
        ) do |error|
          expect(error.message).to include("20240101000000_primary_migration.rb")
          expect(error.message).to_not include("20240102000000_analytics_migration.rb")
        end
      end
    end
  end
end
