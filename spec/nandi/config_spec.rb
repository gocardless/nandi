# frozen_string_literal: true

require "spec_helper"
require "nandi/config"

RSpec.describe Nandi::Config do
  subject(:config) { described_class.new }

  before do
    Nandi.instance_variable_set(:@config, nil) # Reset config
    config.lockfile_directory = "db"
  end

  context "multi-database integration" do
    before do
      config.register_database(
        :primary,
        migration_directory: primary_migration_directory,
        output_directory: primary_output_directory,
      )
      config.register_database(
        :analytics,
        migration_directory: analytics_migration_directory,
        output_directory: analytics_output_directory,
      )
    end

    let(:primary_migration_directory) { "db/primary_migrations" }
    let(:primary_output_directory) { "db/primary_migrate" }
    let(:analytics_migration_directory) { "db/analytics_migrations" }
    let(:analytics_output_directory) { "db/migrate/analytics" }

    it "returns the correct list of names" do
      expect(config.databases.names).to eq(%i[primary analytics])
    end

    it "throws an error if database does not exist" do
      expect { config.migration_directory(:nonexistent) }.to raise_error(ArgumentError)
    end

    it "returns database-specific migration directories" do
      expect(config.migration_directory(:primary)).to eq(primary_migration_directory)
      expect(config.migration_directory(:analytics)).to eq(analytics_migration_directory)
    end

    it "returns database-specific output directories" do
      expect(config.output_directory(:primary)).to eq(primary_output_directory)
      expect(config.output_directory(:analytics)).to eq(analytics_output_directory)
    end

    it "delegates the lockfile path" do
      config.register_database(:new, lockfile_name: ".my_nandilock.yml")
      expect(config.lockfile_path(:new)).to eq("db/.my_nandilock.yml")
    end

    it "returns primary config if name not specified" do
      expect(config.migration_directory).to eq(primary_migration_directory)
      expect(config.output_directory).to eq(primary_output_directory)
    end

    it "returns database-specific lockfile paths in multi-database mode" do
      expect(config.lockfile_path(:primary)).to eq("db/.nandilock.yml")
      expect(config.lockfile_path(:analytics)).to eq("db/.analytics_nandilock.yml")
    end

    it "raises error for invalid database in lockfile_path" do
      expect do
        config.lockfile_path(:nonexistent)
      end.to raise_error(ArgumentError, "Missing database configuration for nonexistent")
    end

    context "with default multi-database configuration" do
      let(:primary_migration_directory) { nil }
      let(:primary_output_directory) { nil }

      it "uses default database config" do
        expect(config.migration_directory(:primary)).to eq("db/safe_migrations")
        expect(config.output_directory(:primary)).to eq("db/migrate")
        expect(config.lockfile_path(:primary)).to eq("db/.nandilock.yml")
      end
    end
  end

  context "with single database configuration" do
    it "returns :primary for the database name" do
      expect(config.databases.names).to eq([:primary])
    end

    it "returns default directory if name not specified" do
      expect(config.migration_directory).to eq("db/safe_migrations")
      expect(config.output_directory).to eq("db/migrate")
    end

    it "raises error for unknown db name" do
      expect do
        config.migration_directory(:any_db)
      end.to raise_error(ArgumentError, "Missing database configuration for any_db")
    end

    it "respects overriding paths" do
      config.migration_directory = "db/safe_migrations/override"
      config.output_directory = "db/migrate/override"

      expect(config.migration_directory).to eq("db/safe_migrations/override")
      expect(config.output_directory).to eq("db/migrate/override")
    end

    it "returns default lockfile path in single-database mode" do
      expect(config.lockfile_path).to eq("db/.nandilock.yml")
    end
  end

  context "validation" do
    it "prevents mixing single and multi-database configuration with migration_directory" do
      config.migration_directory = "db/custom"
      config.register_database(:test, migration_directory: "db/test")

      expect { config.validate! }.to raise_error(
        ArgumentError, /Cannot use multi and single database config/
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
end
