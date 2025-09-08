# frozen_string_literal: true

require "tempfile"

RSpec.describe Nandi::Lockfile do
  before do
    described_class.clear_instances!
    allow(File).to receive(:write).and_call_original
    allow(Nandi.config).to receive(:lockfile_directory).and_return(temp_dir)
  end

  let(:database) { :primary }

  let(:temp_dir) { Dir.mktmpdir }
  let(:lockfile_contents) { "--- {}\n" }

  def write_lockfile!
    allow(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", anything).and_call_original
    File.write("#{temp_dir}/.nandilock.yml", lockfile_contents)
  end

  describe ".for" do
    it "returns same instance for same database" do
      lockfile1 = described_class.for(:primary)
      lockfile2 = described_class.for(:primary)

      expect(lockfile1).to be(lockfile2)
    end

    it "returns different instances for different databases" do
      primary = described_class.for(:primary)
      analytics = described_class.for(:analytics)

      expect(primary).to_not be(analytics)
      expect(primary.db_name).to eq(:primary)
      expect(analytics.db_name).to eq(:analytics)
    end

    it "requires explicit db_name parameter" do
      expect { described_class.for }.to raise_error(ArgumentError)
    end
  end

  describe "#file_present?" do
    let(:lockfile) { described_class.for(database) }

    context "lockfile exists" do
      before { write_lockfile! }

      it { expect(lockfile.file_present?).to eq(true) }
    end

    context "doesn't exist" do
      it { expect(lockfile.file_present?).to eq(false) }
    end
  end

  describe "#create!" do
    let(:lockfile) { described_class.for(database) }

    it "creates a file" do
      expect(File).to receive(:write).
        with("#{temp_dir}/.nandilock.yml", "--- {}\n").
        and_call_original

      lockfile.create!
    end
  end

  describe "#add" do
    let(:lockfile) { described_class.for(database) }
    let(:lockfile_contents) { "--- {}\n" }

    before { write_lockfile! }

    # rubocop:disable RSpec/ExampleLength
    it "adds the digests to the instance" do
      lockfile.add(
        file_name: "file_name",
        source_digest: "source_digest",
        compiled_digest: "compiled_digest",
      )

      result = lockfile.get(file_name: "file_name")
      expect(result[:source_digest]).to eq("source_digest")
      expect(result[:compiled_digest]).to eq("compiled_digest")
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe "#get" do
    let(:lockfile) { described_class.for(database) }

    let(:lockfile_contents) do
      <<~YAML
        ---
        migration1:
          source_digest: "deadbeef1234"
          compiled_digest: "deadbeef5678"
      YAML
    end

    before { write_lockfile! }

    it "retrieves the digests" do
      expect(lockfile.get(file_name: "migration1")).to eq(
        source_digest: "deadbeef1234",
        compiled_digest: "deadbeef5678",
      )
    end
  end

  describe "#persist!" do
    let(:lockfile) { described_class.for(database) }

    let(:expected_yaml) do
      <<~YAML
        ---
        foo:
          source_digest: bar
          compiled_digest: '5'
      YAML
    end

    before do
      write_lockfile!
      lockfile.add(file_name: "foo", source_digest: "bar", compiled_digest: "5")
    end

    it "writes the existing file" do
      expect(File).to receive(:write).with(
        "#{temp_dir}/.nandilock.yml",
        expected_yaml,
      )

      lockfile.persist!
    end

    context "with multiple keys, not sorted by their SHA-256 hash" do
      let(:expected_yaml) do
        <<~YAML
          ---
          lower_hash:
            source_digest: foo
            compiled_digest: '5'
          higher_hash:
            source_digest: foo
            compiled_digest: '5'
        YAML
      end

      let(:test_lockfile) { described_class.for(:isolated_test_db) }

      before do
        allow(Nandi.config).to receive(:lockfile_path).with(:isolated_test_db).
          and_return("#{temp_dir}/.isolated_nandilock.yml")
        File.write("#{temp_dir}/.isolated_nandilock.yml", "--- {}\n")
        test_lockfile.add(file_name: "higher_hash", source_digest: "foo", compiled_digest: "5")
        test_lockfile.add(file_name: "lower_hash", source_digest: "foo", compiled_digest: "5")
      end

      it "sorts the keys by their SHA-256 hash" do
        expect(File).to receive(:write).with(
          "#{temp_dir}/.isolated_nandilock.yml",
          expected_yaml,
        )

        test_lockfile.persist!
      end
    end
  end

  describe "multi-database support" do
    let(:primary_db) { :primary }
    let(:analytics_db) { :analytics }

    before do
      # Mock different lockfile paths for different databases
      allow(Nandi.config).to receive(:lockfile_path).with(primary_db).
        and_return("#{temp_dir}/.nandilock.yml")
      allow(Nandi.config).to receive(:lockfile_path).with(analytics_db).
        and_return("#{temp_dir}/.analytics_nandilock.yml")
    end

    describe "#file_present? with multiple databases" do
      it "checks correct file for each database" do
        # Create only primary lockfile
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")

        expect(described_class.for(primary_db).file_present?).to be true
        expect(described_class.for(analytics_db).file_present?).to be false
      end
    end

    describe "#create! with multiple databases" do
      it "creates separate lockfiles for different databases" do
        expect(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", "--- {}\n")
        expect(File).to receive(:write).with("#{temp_dir}/.analytics_nandilock.yml", "--- {}\n")

        described_class.for(primary_db).create!
        described_class.for(analytics_db).create!
      end

      it "does not re-create existing lockfiles" do
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")

        expect(File).to_not receive(:write).with("#{temp_dir}/.nandilock.yml", anything)

        described_class.for(primary_db).create!
      end
    end

    describe "#add with multiple databases" do
      before do
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")
        File.write("#{temp_dir}/.analytics_nandilock.yml", "--- {}\n")
      end

      let(:add_migrations_to_databases) do
        primary_lockfile = described_class.for(primary_db)
        primary_lockfile.add(
          file_name: "primary_migration",
          source_digest: "primary_source",
          compiled_digest: "primary_compiled",
        )
        primary_lockfile.persist!

        analytics_lockfile = described_class.for(analytics_db)
        analytics_lockfile.add(
          file_name: "analytics_migration",
          source_digest: "analytics_source",
          compiled_digest: "analytics_compiled",
        )
        analytics_lockfile.persist!
      end

      # rubocop: disable RSpec/ExampleLength
      it "adds migrations to correct database lockfile" do
        add_migrations_to_databases

        primary_lockfile = described_class.for(primary_db)
        analytics_lockfile = described_class.for(analytics_db)

        expect(primary_lockfile.get(file_name: "primary_migration")[:source_digest]).
          to eq("primary_source")
        expect(analytics_lockfile.get(file_name: "analytics_migration")[:source_digest]).
          to eq("analytics_source")
        expect(primary_lockfile.get(file_name: "analytics_migration")[:source_digest]).to be_nil
        expect(analytics_lockfile.get(file_name: "primary_migration")[:source_digest]).to be_nil
      end
      # rubocop: enable RSpec/ExampleLength
    end

    describe "#get with multiple databases" do
      before do
        primary_content = <<~YAML
          ---
          shared_name:
            source_digest: "primary_digest"
            compiled_digest: "primary_compiled"
        YAML

        analytics_content = <<~YAML
          ---
          shared_name:
            source_digest: "analytics_digest"
            compiled_digest: "analytics_compiled"
        YAML

        File.write("#{temp_dir}/.nandilock.yml", primary_content)
        File.write("#{temp_dir}/.analytics_nandilock.yml", analytics_content)
      end

      it "retrieves migration from correct database" do
        primary_result = described_class.for(primary_db).get(file_name: "shared_name")
        analytics_result = described_class.for(analytics_db).get(file_name: "shared_name")

        expect(primary_result[:source_digest]).to eq("primary_digest")
        expect(analytics_result[:source_digest]).to eq("analytics_digest")
      end
    end

    describe "#persist! with multiple databases" do
      it "writes only the specific database lockfile" do
        # Setup data in primary lockfile
        primary_lockfile = described_class.for(primary_db)
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")
        primary_lockfile.add(file_name: "migration1", source_digest: "foo", compiled_digest: "bar")

        expect(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", anything)
        expect(File).to_not receive(:write).with("#{temp_dir}/.analytics_nandilock.yml", anything)

        primary_lockfile.persist!
      end
    end
  end

  describe "database validation and error handling" do
    describe "with invalid database configuration" do
      before do
        allow(Nandi.config).to receive(:lockfile_path).with(:invalid_db).and_call_original
      end

      it "propagates configuration errors" do
        expect { described_class.for(:invalid_db).file_present? }.
          to raise_error(ArgumentError, "Missing database configuration for invalid_db")
      end
    end

    describe "with missing lockfile directory" do
      let(:nonexistent_dir) { "/nonexistent/directory" }

      before do
        allow(Nandi.config).to receive(:lockfile_path).with(:test_db).
          and_return("#{nonexistent_dir}/.test_nandilock.yml")
      end

      it "handles missing directory gracefully on file_present?" do
        expect(described_class.for(:test_db).file_present?).to be false
      end

      it "raises error on create! with missing directory" do
        expect { described_class.for(:test_db).create! }.
          to raise_error(Errno::ENOENT)
      end
    end
  end
end
