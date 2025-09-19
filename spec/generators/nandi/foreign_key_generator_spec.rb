# frozen_string_literal: true

require "spec_helper"
require "generators/nandi/foreign_key/foreign_key_generator"

RSpec.describe Nandi::ForeignKeyGenerator do
  let(:generator) { described_class.new(%w[posts users]) }

  before do
    # Reset Nandi configuration
    Nandi.instance_variable_set(:@config, nil)

    # Mock Rails generator methods
    allow(generator).to receive(:template)
    allow(generator).to receive(:options).and_return({})

    # Mock time to ensure consistent timestamps
    allow(Time).to receive(:now).and_return(Time.new(2024, 1, 15, 12, 30, 45, "UTC"))
  end

  describe "#add_reference" do
    before do
      Nandi.configure do |config|
        config.migration_directory = "db/safe_migrations"
      end
    end

    it "creates reference migration file" do
      expect(generator).to receive(:template).with(
        "add_reference.rb",
        "db/safe_migrations/20240115123045_add_reference_on_posts_to_users.rb",
      )

      generator.add_reference
    end

    it "sets correct add_reference_name" do
      allow(generator).to receive(:template)

      generator.add_reference

      expect(generator.add_reference_name).to eq("add_reference_on_posts_to_users")
    end

    context "with no_create_column option" do
      before do
        allow(generator).to receive(:options).and_return({ "no_create_column" => true })
      end

      it "does not create reference migration" do
        expect(generator).to_not receive(:template)

        generator.add_reference
      end
    end
  end

  describe "#add_foreign_key" do
    before do
      Nandi.configure do |config|
        config.migration_directory = "db/safe_migrations"
      end
    end

    it "creates foreign key migration file" do
      expect(generator).to receive(:template).with(
        "add_foreign_key.rb",
        "db/safe_migrations/20240115123046_add_foreign_key_on_posts_to_users.rb",
      )

      generator.add_foreign_key
    end
  end

  describe "#validate_foreign_key" do
    before do
      Nandi.configure do |config|
        config.migration_directory = "db/safe_migrations"
      end
    end

    it "creates validation migration file" do
      expect(generator).to receive(:template).with(
        "validate_foreign_key.rb",
        "db/safe_migrations/20240115123047_validate_foreign_key_on_posts_to_users.rb",
      )

      generator.validate_foreign_key
    end
  end

  describe "multi-database support" do
    before do
      Nandi.configure do |config|
        config.register_database(:primary, migration_directory: "db/primary_safe_migrations")
        config.register_database(:analytics, migration_directory: "db/analytics_safe_migrations")
      end

      allow(generator).to receive(:options).and_return({ "database" => "analytics" })
    end

    it "creates reference migration in correct database directory" do
      expect(generator).to receive(:template).with(
        "add_reference.rb",
        "db/analytics_safe_migrations/20240115123045_add_reference_on_posts_to_users.rb",
      )

      generator.add_reference
    end

    it "creates foreign key migration in correct database directory" do
      expect(generator).to receive(:template).with(
        "add_foreign_key.rb",
        "db/analytics_safe_migrations/20240115123046_add_foreign_key_on_posts_to_users.rb",
      )

      generator.add_foreign_key
    end

    it "creates validation migration in correct database directory" do
      expect(generator).to receive(:template).with(
        "validate_foreign_key.rb",
        "db/analytics_safe_migrations/20240115123047_validate_foreign_key_on_posts_to_users.rb",
      )

      generator.validate_foreign_key
    end
  end
end
