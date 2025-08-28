# frozen_string_literal: true

require "spec_helper"
require "nandi/multi_database"

RSpec.describe Nandi::MultiDatabase do
  subject(:multi_db) { described_class.new }

  context "when no databases are registered" do
    it "returns empty names array" do
      expect(multi_db.names).to eq([])
    end

    it "raises error when accessing config" do
      expect do
        multi_db.config(:nonexistent)
      end.to raise_error(ArgumentError, "Missing database configuration for nonexistent")
    end

    it "returns nil for default database" do
      expect(multi_db.default).to be_nil
    end
  end

  context "when databases are registered" do
    before do
      multi_db.register(:primary, migration_directory: "db/safe_migrations", output_directory: "db/migrate")
      multi_db.register(:analytics, migration_directory: "db/analytics", output_directory: "db/migrate/analytics")
    end

    it "returns correct database names" do
      expect(multi_db.names).to contain_exactly(:primary, :analytics)
    end

    it "returns correct database config for primary" do
      primary_config = multi_db.config(:primary)
      expect(primary_config.name).to eq(:primary)
      expect(primary_config.migration_directory).to eq("db/safe_migrations")
      expect(primary_config.output_directory).to eq("db/migrate")
    end

    it "returns correct database config for analytics" do
      analytics_config = multi_db.config(:analytics)
      expect(analytics_config.name).to eq(:analytics)
      expect(analytics_config.migration_directory).to eq("db/analytics")
      expect(analytics_config.output_directory).to eq("db/migrate/analytics")
    end

    it "returns primary database as default when no database name specified" do
      expect(multi_db.config(nil).name).to eq(:primary)
    end

    it "identifies default database correctly" do
      expect(multi_db.default.name).to eq(:primary)
    end

    it "raises error for duplicate database registration" do
      expect do
        multi_db.register(:primary, migration_directory: "db/new")
      end.to raise_error(ArgumentError, "Database primary already registered")
    end

    it "converts string names to symbols" do
      multi_db.register("string_name", migration_directory: "db/string")
      expect(multi_db.names).to include(:string_name)
    end
  end

  context "default database behavior" do
    context "when primary database is registered" do
      before do
        multi_db.register(:primary, migration_directory: "db/primary")
        multi_db.register(:analytics, migration_directory: "db/analytics")
      end

      it "automatically treats primary as default" do
        expect(multi_db.default.name).to eq(:primary)
        expect(multi_db.default.default).to be true
      end

      it "returns primary database when no database name specified" do
        expect(multi_db.config(nil).name).to eq(:primary)
        expect(multi_db.config.name).to eq(:primary)
      end
    end

    context "when explicit default: true is used" do
      before do
        multi_db.register(:main, migration_directory: "db/main", default: true)
        multi_db.register(:analytics, migration_directory: "db/analytics")
      end

      it "treats explicitly marked database as default" do
        expect(multi_db.default.name).to eq(:main)
        expect(multi_db.default.default).to be true
      end

      it "returns explicit default database when no database name specified" do
        expect(multi_db.config(nil).name).to eq(:main)
        expect(multi_db.config.name).to eq(:main)
      end

      it "other databases are not default" do
        analytics_db = multi_db.config(:analytics)
        expect(analytics_db.default).to be false
      end
    end

    context "when both primary and explicit default: true are used" do
      before do
        multi_db.register(:primary, migration_directory: "db/primary")
        multi_db.register(:main, migration_directory: "db/main", default: true)
      end

      it "raises error during validation due to multiple defaults" do
        expect { multi_db.validate! }.to raise_error(
          ArgumentError, "Multiple default databases specified: primary, main"
        )
      end
    end
  end

  context "validation" do
    context "when databases are registered" do
      it "raises error when no default database is specified" do
        multi_db.register(:db1, migration_directory: "db/db1")
        multi_db.register(:db2, migration_directory: "db/db2")

        expect { multi_db.validate! }.to raise_error(
          ArgumentError, /Missing default database/
        )
      end

      it "automatically treats primary database as default" do
        multi_db.register(:primary, migration_directory: "db/primary")
        multi_db.register(:analytics, migration_directory: "db/analytics")

        expect { multi_db.validate! }.to_not raise_error
      end

      it "allows explicit default database specification" do
        multi_db.register(:main, migration_directory: "db/main", default: true)
        multi_db.register(:analytics, migration_directory: "db/analytics")

        expect { multi_db.validate! }.to_not raise_error
      end

      it "raises error for duplicate migration directories" do
        multi_db.register(:primary, migration_directory: "db/same", output_directory: "db/migrate1")
        multi_db.register(:db2, migration_directory: "db/same", output_directory: "db/migrate2")

        expect { multi_db.validate! }.to raise_error(
          ArgumentError, "Unique migration directories must be specified for each database"
        )
      end

      it "raises error for duplicate output directories" do
        multi_db.register(:primary, migration_directory: "db/db1", output_directory: "db/migrate")
        multi_db.register(:db2, migration_directory: "db/db2", output_directory: "db/migrate")

        expect { multi_db.validate! }.to raise_error(
          ArgumentError, "Unique output directories must be specified for each database"
        )
      end
    end
  end

  context "with lockfile behavior" do
    it "uses prefixed default lockfile when not specified" do
      multi_db.register(:test, {})
      config = multi_db.config(:test)

      expect(config.lockfile_name).to eq(".test_nandilock.yml")
    end

    it "allows custom lockfile names" do
      multi_db.register(:custom, lockfile_name: ".custom_lock.yml")
      config = multi_db.config(:custom)

      expect(config.lockfile_name).to eq(".custom_lock.yml")
    end
  end

  describe "Database" do
    subject(:database) { Nandi::MultiDatabase::Database.new(name: name, config: config) }

    context "with valid configuration" do
      let(:name) { :test_db }
      let(:config) do
        {
          migration_directory: "db/test/migrations",
          output_directory: "db/test/migrate",
          lockfile_name: ".test_lock.yml",
        }
      end

      it "sets name correctly" do
        expect(database.name).to eq(:test_db)
      end

      it "sets directories correctly" do
        expect(database.migration_directory).to eq("db/test/migrations")
        expect(database.output_directory).to eq("db/test/migrate")
      end

      it "sets lockfile name correctly" do
        expect(database.lockfile_name).to eq(".test_lock.yml")
      end

      it "is not default by default" do
        expect(database.default).to be_falsy
      end
    end

    context "with minimal configuration" do
      let(:name) { :minimal }
      let(:config) { {} }

      it "uses default prefixed directories" do
        expect(database.migration_directory).to eq("db/minimal_safe_migrations")
        expect(database.output_directory).to eq("db/minimal_migrate")
      end

      it "uses default prefixed lockfile name" do
        expect(database.lockfile_name).to eq(".minimal_nandilock.yml")
      end
    end

    context "with primary database" do
      let(:name) { :primary }
      let(:config) { {} }

      it "automatically sets as default" do
        expect(database.default).to be true
      end
    end

    context "with explicit default flag" do
      let(:name) { :custom }
      let(:config) { { default: true } }

      it "respects explicit default setting" do
        expect(database.default).to be true
      end
    end

    context "partial configuration" do
      let(:name) { :partial }

      context "with only migration directory specified" do
        let(:config) { { migration_directory: "custom/migrations" } }

        it "uses custom migration directory and default output directory" do
          expect(database.migration_directory).to eq("custom/migrations")
          expect(database.output_directory).to eq("db/partial_migrate")
        end
      end

      context "with only output directory specified" do
        let(:config) { { output_directory: "custom/output" } }

        it "uses default migration directory and custom output directory" do
          expect(database.migration_directory).to eq("db/partial_safe_migrations")
          expect(database.output_directory).to eq("custom/output")
        end
      end

      context "with only lockfile name specified" do
        let(:config) { { lockfile_name: ".custom.yml" } }

        it "uses custom lockfile name and default directories" do
          expect(database.lockfile_name).to eq(".custom.yml")
          expect(database.migration_directory).to eq("db/partial_safe_migrations")
          expect(database.output_directory).to eq("db/partial_migrate")
        end
      end
    end
  end
end
