# frozen_string_literal: true

require "spec_helper"
require "generators/nandi/migration/migration_generator"

RSpec.describe Nandi::MigrationGenerator do
  before do
    # Reset config
    Nandi.instance_variable_set(:@config, nil)
  end

  describe "single database mode" do
    it "generates migration in default directory" do
      generator = described_class.new(["create_users"])
      expect(generator.send(:base_path)).to eq("db/safe_migrations")
    end

    it "has no db name when none specified" do
      generator = described_class.new(["create_users"])
      expect(generator.send(:db_name)).to be_nil
    end
  end

  describe "multi-database mode" do
    before do
      Nandi.configure do |config|
        config.register_database(:primary, {
          migration_directory: "db/safe_migrations/primary",
          output_directory: "db/migrate/primary",
        })
        config.register_database(:analytics, {
          migration_directory: "db/safe_migrations/analytics",
          output_directory: "db/migrate/analytics",
        })
      end
    end

    it "generates migration in database-specific directory when specified" do
      generator = described_class.new(["create_users"], { database: "analytics" })

      expect(generator.send(:base_path)).to eq("db/safe_migrations/analytics")
      expect(generator.send(:db_name)).to eq(:analytics)
    end

    it "generates migration in database-specific directory for analytics" do
      generator = described_class.new(["create_reports"], { database: "analytics" })

      expect(generator.send(:base_path)).to eq("db/safe_migrations/analytics")
      expect(generator.send(:db_name)).to eq(:analytics)
    end

    it "falls back to primary directory when no database specified" do
      generator = described_class.new(["create_logs"])

      expect(generator.send(:base_path)).to eq("db/safe_migrations/primary")
      expect(generator.send(:db_name)).to be_nil
    end

    it "handles non-existent database gracefully" do
      expect do
        generator = described_class.new(["create_widgets"], { database: "nonexistent" })
        generator.send(:base_path)
      end.to raise_error(ArgumentError, "Missing database configuration for nonexistent")
    end
  end

  describe "dbname method" do
    it "returns symbol when database option provided" do
      generator = described_class.new(["test"], { database: "analytics" })
      expect(generator.send(:db_name)).to eq(:analytics)
    end

    it "returns nil when no database option provided" do
      generator = described_class.new(["test"], {})
      expect(generator.send(:db_name)).to be_nil
    end
  end
end
