# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/validator"
require "nandi/config"
require "nandi/compiled_migration"
require "nandi/lockfile"

RSpec.describe Nandi do
  let(:validator) { Nandi::Validator }

  before do
    # Reset config before each test
    described_class.instance_variable_set(:@config, nil)
  end

  describe "Configuration" do
    context "with multi-database configuration" do
      before do
        described_class.configure do |config|
          config.databases = {
            primary: { migration_directory: "db/safe_migrations/primary" },
            analytics: {
              migration_directory: "db/safe_migrations/analytics",
              output_directory: "db/migrate/analytics",
            },
          }
        end
      end

      it "reports as multi-database enabled" do
        expect(described_class.config.multi_database?).to be true
      end

      it "returns correct database names" do
        expect(described_class.config.database_names).to eq(%i[primary analytics])
      end

      it "returns database-specific migration directories" do
        expect(described_class.config.migration_directory_for(:primary)).to eq("db/safe_migrations/primary")
        expect(described_class.config.migration_directory_for(:analytics)).to eq("db/safe_migrations/analytics")
        expect(described_class.config.migration_directory_for(:nonexistent)).to eq("db/safe_migrations")
      end

      it "returns database-specific output directories" do
        expect(described_class.config.output_directory_for(:primary)).to eq("db/migrate")
        expect(described_class.config.output_directory_for(:analytics)).to eq("db/migrate/analytics")
      end
    end

    context "with single database configuration" do
      it "reports as single database" do
        expect(described_class.config.multi_database?).to be false
      end

      it "returns default directories" do
        expect(described_class.config.migration_directory_for(:any_db)).to eq("db/safe_migrations")
        expect(described_class.config.output_directory_for(:any_db)).to eq("db/migrate")
      end
    end

    describe "validation" do
      it "validates database configurations" do # rubocop:disable RSpec/ExampleLength
        config = Nandi::Config.new
        config.databases = {
          invalid: "not a hash",
        }

        expect { config.validate_databases! }.to raise_error(
          ArgumentError, "Database config for invalid must be a Hash"
        )
      end

      it "requires migration_directory for each database" do # rubocop:disable RSpec/ExampleLength
        config = Nandi::Config.new
        config.databases = {
          primary: { output_directory: "db/migrate/primary" },
        }

        expect { config.validate_databases! }.to raise_error(
          ArgumentError, "Database config for primary must specify :migration_directory"
        )
      end
    end
  end

  describe "Migration class" do
    context "with database declaration" do
      subject(:migration) { migration_class.new(validator) }

      let(:migration_class) do
        Class.new(Nandi::Migration) do
          database :analytics
          def up; end
        end
      end

      it "stores the target database on the class" do
        expect(migration_class.target_database).to eq(:analytics)
      end

      it "returns the target database from instance" do
        expect(migration.target_database).to eq(:analytics)
      end
    end

    context "without database declaration" do
      subject(:migration) { migration_class.new(validator) }

      let(:migration_class) do
        Class.new(Nandi::Migration) do
          def up; end
        end
      end

      it "returns nil for target database" do
        expect(migration.target_database).to be_nil
      end
    end
  end

  describe "Lockfile" do
    before do
      allow(Nandi::Lockfile).to receive(:load!)
      allow(Nandi::Lockfile).to receive(:lockfile).and_return({})
    end

    describe ".add" do
      it "stores database-specific entries" do # rubocop:disable RSpec/ExampleLength
        expect(Nandi::Lockfile.lockfile).to receive(:[]=).with(
          "analytics/20240101120000_test_migration.rb",
          hash_including(
            source_digest: "source123",
            compiled_digest: "compiled123",
            database: :analytics,
          ),
        )

        Nandi::Lockfile.add(
          file_name: "20240101120000_test_migration.rb",
          source_digest: "source123",
          compiled_digest: "compiled123",
          database: :analytics,
        )
      end

      it "stores non-database entries without prefix" do # rubocop:disable RSpec/ExampleLength
        expect(Nandi::Lockfile.lockfile).to receive(:[]=).with(
          "20240101120000_test_migration.rb",
          hash_including(
            source_digest: "source123",
            compiled_digest: "compiled123",
          ),
        )

        Nandi::Lockfile.add(
          file_name: "20240101120000_test_migration.rb",
          source_digest: "source123",
          compiled_digest: "compiled123",
        )
      end
    end

    describe ".get" do
      before do
        allow(Nandi::Lockfile).to receive(:lockfile).and_return({
          "analytics/20240101120000_test_migration.rb" => {
            source_digest: "analytics_source",
            compiled_digest: "analytics_compiled",
            database: :analytics,
          },
          "20240101120000_other_migration.rb" => {
            source_digest: "default_source",
            compiled_digest: "default_compiled",
          },
        })
      end

      it "retrieves database-specific entries" do
        result = Nandi::Lockfile.get("20240101120000_test_migration.rb", database: :analytics)

        expect(result).to eq({
          source_digest: "analytics_source",
          compiled_digest: "analytics_compiled",
          database: :analytics,
        })
      end

      it "falls back to non-prefixed entry when database specified but not found" do
        result = Nandi::Lockfile.get("20240101120000_other_migration.rb", database: :analytics)

        expect(result).to eq({
          source_digest: "default_source",
          compiled_digest: "default_compiled",
          database: nil,
        })
      end

      it "retrieves non-database entries" do
        result = Nandi::Lockfile.get("20240101120000_other_migration.rb")

        expect(result).to eq({
          source_digest: "default_source",
          compiled_digest: "default_compiled",
        })
      end
    end
  end

  describe "Backward compatibility" do
    subject(:migration) { legacy_migration_class.new(validator) }

    let(:legacy_migration_class) do
      Class.new(Nandi::Migration) do
        def up
          create_table :users do |t|
            t.text :name
          end
        end

        def down
          drop_table :users
        end
      end
    end

    it "works without database declaration" do
      expect(migration.target_database).to be_nil
      expect { migration.up_instructions }.to_not raise_error
    end

    it "generates correct output path without database" do
      # Mock file system to avoid requiring actual migration file
      compiled_migration = instance_double(Nandi::CompiledMigration)
      allow(compiled_migration).to receive_messages(migration: migration, file_name: "test.rb")

      expect(described_class.config.output_directory_for(nil)).to eq("db/migrate")
    end
  end
end
