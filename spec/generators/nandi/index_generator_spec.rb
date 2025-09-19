# frozen_string_literal: true

require "spec_helper"
require "generators/nandi/index/index_generator"

RSpec.describe Nandi::IndexGenerator do
  let(:generator) { described_class.new(["users", "email,status"]) }

  before do
    # Reset Nandi configuration
    Nandi.instance_variable_set(:@config, nil)

    # Mock Rails generator methods
    allow(generator).to receive(:template)
    allow(generator).to receive(:options).and_return({})

    # Mock time to ensure consistent timestamps
    allow(Time).to receive(:now).and_return(Time.new(2024, 1, 15, 12, 30, 45, "UTC"))
  end

  describe "#add_index" do
    context "with single table and columns" do
      before do
        Nandi.configure do |config|
          config.migration_directory = "db/safe_migrations"
        end
      end

      it "creates index migration file with correct naming" do
        expect(generator).to receive(:template).with(
          "add_index.rb",
          "db/safe_migrations/20240115123045_add_index_on_email_status_to_users.rb",
        )

        generator.add_index
      end

      it "sets correct instance variables" do
        allow(generator).to receive(:template)

        generator.add_index

        expect(generator.table).to eq(:users)
        expect(generator.columns).to eq(%w[email status])
        expect(generator.add_index_name).to eq("add_index_on_email_status_to_users")
        expect(generator.index_name).to eq(:idx_users_on_email_status)
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

      it "creates index migration in correct database directory" do
        expect(generator).to receive(:template).with(
          "add_index.rb",
          "db/analytics_safe_migrations/20240115123045_add_index_on_email_status_to_users.rb",
        )

        generator.add_index
      end
    end
  end
end
