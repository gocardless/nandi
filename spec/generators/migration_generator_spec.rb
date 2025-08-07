# frozen_string_literal: true

require "spec_helper"
require "rails/generators/test_case"
require "generators/nandi/migration/migration_generator"
require "tmpdir"

RSpec.describe Nandi::MigrationGenerator, type: :generator do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  before do
    # Reset config
    Nandi.instance_variable_set(:@config, nil)
  end

  describe "single database mode" do
    it "generates migration in default directory" do
      # Mock Rails generators infrastructure 
      generator = described_class.new(["create_users"])
      
      expect(generator.send(:base_path)).to eq("db/safe_migrations")
    end
  end

  describe "multi-database mode" do
    before do
      Nandi.configure do |config|
        config.databases = {
          primary: { migration_directory: "db/safe_migrations/primary" },
          analytics: { migration_directory: "db/safe_migrations/analytics" }
        }
      end
    end

    it "generates migration in database-specific directory when specified" do
      generator = described_class.new(["create_users"], { database: "primary" })
      
      expect(generator.send(:base_path)).to eq("db/safe_migrations/primary")
      expect(generator.send(:target_database)).to eq(:primary)
    end

    it "generates migration in database-specific directory for analytics" do
      generator = described_class.new(["create_reports"], { database: "analytics" })
      
      expect(generator.send(:base_path)).to eq("db/safe_migrations/analytics")
      expect(generator.send(:target_database)).to eq(:analytics)
    end

    it "falls back to default directory when no database specified" do
      generator = described_class.new(["create_logs"])
      
      expect(generator.send(:base_path)).to eq("db/safe_migrations")
      expect(generator.send(:target_database)).to be_nil
    end

    it "handles non-existent database gracefully" do
      generator = described_class.new(["create_widgets"], { database: "nonexistent" })
      
      # Should still work, using the fallback directory
      expect(generator.send(:base_path)).to eq("db/safe_migrations")
    end
  end

  describe "template rendering" do
    before do
      Nandi.configure do |config|
        config.databases = {
          primary: { migration_directory: "#{@tmpdir}/db/safe_migrations/primary" }
        }
      end
      
      FileUtils.mkdir_p("#{@tmpdir}/db/safe_migrations/primary")
    end

    # This would require setting up full Rails generator test infrastructure
    # For now, let's just test the logic components
    it "includes database declaration in template context" do
      generator = described_class.new(["create_users"], { database: "primary" })
      
      expect(generator.send(:target_database)).to eq(:primary)
    end
  end
end