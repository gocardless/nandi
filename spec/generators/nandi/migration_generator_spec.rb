# frozen_string_literal: true

require "spec_helper"
require "generators/nandi/migration/migration_generator"

RSpec.describe Nandi::MigrationGenerator do
  let(:generator) { described_class.new(["add_users_table"]) }

  before do
    # Reset Nandi configuration
    Nandi.instance_variable_set(:@config, nil)

    # Mock Rails generator methods
    allow(generator).to receive(:template)
    allow(generator).to receive(:options).and_return({})

    # Mock time to ensure consistent timestamps in tests
    allow(Time).to receive(:now).and_return(Time.new(2024, 1, 15, 12, 30, 45, "UTC"))
  end

  describe "#create_migration_file" do
    context "with default single database configuration" do
      before do
        Nandi.configure do |config|
          config.migration_directory = "db/safe_migrations"
        end
      end

      it "creates migration file with timestamp and underscored name" do
        expect(generator).to receive(:template).with(
          "migration.rb",
          "db/safe_migrations/20240115123045_add_users_table.rb",
        )

        generator.create_migration_file
      end
    end

    context "with multi-database configuration" do
      before do
        Nandi.configure do |config|
          config.register_database(:primary, migration_directory: "db/primary_safe_migrations")
          config.register_database(:analytics, migration_directory: "db/analytics_safe_migrations")
        end

        allow(generator).to receive(:options).and_return({ "database" => "analytics" })
      end

      it "creates migration file in correct database directory" do
        expect(generator).to receive(:template).with(
          "migration.rb",
          "db/analytics_safe_migrations/20240115123045_add_users_table.rb",
        )

        generator.create_migration_file
      end
    end
  end
end
