# frozen_string_literal: true

require "spec_helper"
require "generators/nandi/compile/compile_generator"

RSpec.describe Nandi::CompileGenerator do
  let(:generator) { described_class.new }
  let(:temp_dir) { "/tmp/nandi_spec" }

  before do
    # Reset Nandi configuration before each test
    Nandi.instance_variable_set(:@config, nil)

    # Clear existing lockfiles
    Nandi::Lockfile.lockfiles.clear

    # Mock file operations only - no filesystem access
    allow(File).to receive(:write)
    allow(File).to receive(:read).and_return("migration content")

    # Mock Dir.chdir to prevent actual directory changes and return file list
    allow(Dir).to receive(:chdir).and_yield
    allow(Dir).to receive(:[]).with("*.rb").and_return(["test_migration.rb"])

    # Mock FileMatcher to return the files as-is by default
    allow(Nandi::FileMatcher).to receive(:call).and_return(["test_migration.rb"])

    # Mock generator Rails methods
    allow(generator).to receive(:options).and_return({})
    allow(generator).to receive(:create_file)
  end

  describe "single database configuration" do
    before do
      Nandi.configure do |config|
        config.migration_directory = "#{temp_dir}/db/safe_migrations"
        config.output_directory = "#{temp_dir}/db/migrate"
        config.lockfile_directory = temp_dir
      end

      # Mock Nandi.compile
      allow(Nandi).to receive(:compile).and_yield([
        instance_double(
          Nandi::CompiledMigration,
          file_name: "test_migration.rb",
          source_digest: "abc123",
          compiled_digest: "def456",
          migration_unchanged?: false,
          output_path: "#{temp_dir}/db/migrate/test_migration.rb",
          body: "compiled content",
        ),
      ])

      # Mock lockfile operations
      allow(Nandi::Lockfile).to receive(:add)
      allow(Nandi::Lockfile).to receive(:persist!)
    end

    it "calls Nandi.compile with correct parameters" do
      expect(Nandi).to receive(:compile).with(
        files: ["test_migration.rb"],
        db_name: :primary,
      )

      generator.compile_migration_files
    end

    it "adds entries to lockfile with database context" do
      expect(Nandi::Lockfile).to receive(:add).with(
        hash_including(file_name: "test_migration.rb", db_name: :primary),
      )

      generator.compile_migration_files
    end

    it "creates output files when migration has changed" do
      expect(generator).to receive(:create_file).with(
        "#{temp_dir}/db/migrate/test_migration.rb",
        "compiled content",
        force: true,
      )

      generator.compile_migration_files
    end

    context "when migration is unchanged" do
      before do
        allow(Nandi).to receive(:compile).and_yield([
          instance_double(
            Nandi::CompiledMigration,
            file_name: "test_migration.rb",
            source_digest: "abc123",
            compiled_digest: "def456",
            migration_unchanged?: true,
          ),
        ])
      end

      it "does not create files" do
        expect(generator).to_not receive(:create_file)
        generator.compile_migration_files
      end
    end

    it "persists lockfile after processing" do
      expect(Nandi::Lockfile).to receive(:persist!).once

      generator.compile_migration_files
    end
  end

  describe "multi-database configuration" do
    before do
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

      # Mock file operations for both directories
      allow(Dir).to receive(:chdir).with("#{temp_dir}/db/safe_migrations").and_yield
      allow(Dir).to receive(:chdir).with("#{temp_dir}/db/analytics_safe_migrations").and_yield

      call_count = 0
      allow(Dir).to receive(:[]).with("*.rb") do
        call_count += 1
        case call_count
        when 1
          ["primary_migration.rb"]
        when 2
          ["analytics_migration.rb"]
        else
          []
        end
      end

      # Mock FileMatcher for multi-database
      allow(Nandi::FileMatcher).to receive(:call).with(
        files: ["primary_migration.rb"],
        spec: nil,
      ).and_return(["primary_migration.rb"])

      allow(Nandi::FileMatcher).to receive(:call).with(
        files: ["analytics_migration.rb"],
        spec: nil,
      ).and_return(["analytics_migration.rb"])

      # Mock lockfile operations
      allow(Nandi::Lockfile).to receive(:add)
      allow(Nandi::Lockfile).to receive(:persist!)
    end

    context "when compiling all databases" do
      before do
        # Mock Nandi.compile for both databases
        allow(Nandi).to receive(:compile).with(
          files: ["primary_migration.rb"],
          db_name: :primary,
        ).and_yield([
          instance_double(
            Nandi::CompiledMigration,
            file_name: "primary_migration.rb",
            source_digest: "primary_abc",
            compiled_digest: "primary_def",
            migration_unchanged?: false,
            output_path: "#{temp_dir}/db/migrate/primary_migration.rb",
            body: "primary compiled content",
          ),
        ])

        allow(Nandi).to receive(:compile).with(
          files: ["analytics_migration.rb"],
          db_name: :analytics,
        ).and_yield([
          instance_double(
            Nandi::CompiledMigration,
            file_name: "analytics_migration.rb",
            source_digest: "analytics_abc",
            compiled_digest: "analytics_def",
            migration_unchanged?: false,
            output_path: "#{temp_dir}/db/analytics_migrate/analytics_migration.rb",
            body: "analytics compiled content",
          ),
        ])
      end

      it "processes all configured databases" do
        expect(Nandi).to receive(:compile).twice
        generator.compile_migration_files
      end

      it "adds migrations to lockfile with correct database context" do
        expect(Nandi::Lockfile).to receive(:add).twice
        generator.compile_migration_files
      end

      it "creates files in correct database-specific output directories" do
        expect(generator).to receive(:create_file).twice
        generator.compile_migration_files
      end
    end

    context "when compiling specific database" do
      before do
        allow(generator).to receive(:options).and_return({ database: "analytics" })

        # Override Dir calls for single database
        allow(Dir).to receive(:chdir).with("#{temp_dir}/db/analytics_safe_migrations").and_yield
        allow(Dir).to receive(:[]).with("*.rb").and_return(["analytics_migration.rb"])

        # Mock FileMatcher for specific database
        allow(Nandi::FileMatcher).to receive(:call).with(
          files: ["analytics_migration.rb"],
          spec: nil,
        ).and_return(["analytics_migration.rb"])

        allow(Nandi).to receive(:compile).with(
          files: ["analytics_migration.rb"],
          db_name: "analytics",
        ).and_yield([
          instance_double(
            Nandi::CompiledMigration,
            file_name: "analytics_migration.rb",
            source_digest: "analytics_abc",
            compiled_digest: "analytics_def",
            migration_unchanged?: false,
            output_path: "#{temp_dir}/db/analytics_migrate/analytics_migration.rb",
            body: "analytics compiled content",
          ),
        ])
      end

      it "processes only the specified database" do
        expect(Nandi).to receive(:compile).once
        generator.compile_migration_files
      end
    end
  end

  describe "file filtering with FileMatcher" do
    before do
      Nandi.configure do |config|
        config.migration_directory = "#{temp_dir}/db/safe_migrations"
        config.output_directory = "#{temp_dir}/db/migrate"
        config.lockfile_directory = temp_dir
      end

      # Mock multiple files
      allow(Dir).to receive(:[]).with("*.rb").and_return([
        "20240101000000_first.rb",
        "20240102000000_second.rb",
        "20240103000000_third.rb",
      ])

      allow(Nandi).to receive(:compile).and_yield([])
      allow(Nandi::Lockfile).to receive(:add)
      allow(Nandi::Lockfile).to receive(:persist!)
    end

    it "uses FileMatcher to filter files" do
      allow(generator).to receive(:options).and_return({ "files" => "20240102" })
      expect(Nandi::FileMatcher).to receive(:call).with(
        hash_including(spec: "20240102"),
      ).and_return(["20240102000000_second.rb"])

      generator.compile_migration_files
    end
  end
end
