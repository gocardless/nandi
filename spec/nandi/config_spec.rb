# frozen_string_literal: true

require "spec_helper"
require "nandi/config"

RSpec.describe Nandi::Config do
  context "multi-database integration" do
    subject(:config) { described_class.new }

    before do
      config.lockfile_directory = "db"

      config.register_database(
        :primary,
        migration_directory: "db/safe_migrations",
        output_directory: "db/migrate",
      )
      config.register_database(
        :analytics,
        migration_directory: "db/safe_migrations/analytics",
        output_directory: "db/migrate/analytics",
      )
    end

    it "delegates enabled? to multi_database" do
      expect(config.multi_database_enabled?).to be true
    end

    it "gets the correct list of names" do
      expect(config.database_names).to eq(%i[primary analytics])
    end

    it "throws an error if database does not exist" do
      expect { config.migration_directory(:nonexistent) }.to raise_error(ArgumentError)
    end

    it "returns database-specific migration directories" do
      expect(config.migration_directory(:primary)).to eq("db/safe_migrations")
      expect(config.migration_directory(:analytics)).to eq("db/safe_migrations/analytics")
    end

    it "returns database-specific output directories" do
      expect(config.output_directory(:primary)).to eq("db/migrate")
      expect(config.output_directory(:analytics)).to eq("db/migrate/analytics")
    end

    it "delegates the lockfile path" do
      config.register_database(:new, lockfile_name: ".my_nandilock.yml")
      expect(config.lockfile_path(:new)).to eq("db/.my_nandilock.yml")
    end
  end

  context "with single database configuration" do
    subject(:config) { described_class.new }

    it "reports as single database" do
      expect(config.multi_database_enabled?).to be false
    end

    it "returns nil for the database name" do
      expect(config.database_names).to be_nil
    end

    it "returns default directory if name not specified" do
      expect(config.migration_directory).to eq("db/safe_migrations")
      expect(config.output_directory).to eq("db/migrate")
    end

    it "returns default directories ignoring db name" do
      expect(config.migration_directory(:any_db)).to eq("db/safe_migrations")
      expect(config.output_directory(:any_db)).to eq("db/migrate")
    end

    it "respects overriding paths" do
      config.migration_directory = "db/safe_migrations/override"
      config.output_directory = "db/migrate/override"

      expect(config.migration_directory).to eq("db/safe_migrations/override")
      expect(config.output_directory).to eq("db/migrate/override")
    end
  end

  context "validation" do
    subject(:config) { described_class.new }

    it "prevents mixing single and multi-database configuration with migration_directory" do
      config.migration_directory = "db/custom"
      config.register_database(:test, migration_directory: "db/test")

      expect { config.validate! }.to raise_error(
        ArgumentError, "Cannot specify both `databases` and `migration_directory`/`output_directory`"
      )
    end

    it "prevents mixing single and multi-database configuration with output_directory" do
      config.output_directory = "db/custom_migrate"
      config.register_database(:test, output_directory: "db/test_migrate")

      expect { config.validate! }.to raise_error(
        ArgumentError, "Cannot specify both `databases` and `migration_directory`/`output_directory`"
      )
    end

    it "delegates multi-database validation to multi_database" do
      expect_any_instance_of(Nandi::MultiDatabase).to receive(:validate!)
      config.register_database(:primary, migration_directory: "db/primary")

      config.validate!
    end

    it "validates successfully with single-database configuration" do
      config.migration_directory = "db/custom"

      expect { config.validate! }.to_not raise_error
    end
  end

  context "lockfile integration" do
    subject(:config) { described_class.new }

    before do
      config.lockfile_directory = "db"
    end

    it "returns default lockfile path in single-database mode" do
      expect(config.lockfile_path).to eq("db/.nandilock.yml")
    end

    it "returns database-specific lockfile paths in multi-database mode" do
      config.register_database(:primary, migration_directory: "db/primary")
      config.register_database(:analytics, migration_directory: "db/analytics")

      expect(config.lockfile_path(:primary)).to eq("db/.primary_nandilock.yml")
      expect(config.lockfile_path(:analytics)).to eq("db/.analytics_nandilock.yml")
    end

    it "raises error for invalid database in lockfile_path" do
      config.register_database(:primary, migration_directory: "db/primary")

      expect do
        config.lockfile_path(:nonexistent)
      end.to raise_error(ArgumentError, "Missing database configuration for nonexistent")
    end
  end

  context "constants" do
    it "defines default directories" do
      expect(Nandi::Config::DEFAULT_MIGRATION_DIRECTORY).to eq("db/safe_migrations")
      expect(Nandi::Config::DEFAULT_OUTPUT_DIRECTORY).to eq("db/migrate")
    end
  end
end
