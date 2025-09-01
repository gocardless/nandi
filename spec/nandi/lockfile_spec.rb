# frozen_string_literal: true

require "tempfile"

RSpec.describe Nandi::Lockfile do
  before do
    allow(File).to receive(:write).and_call_original
    allow(Nandi.config).to receive(:lockfile_directory).and_return(temp_dir)
    described_class.lockfiles[database] = nil
  end

  let(:database) { :primary }

  let(:temp_dir) { Dir.mktmpdir }
  let(:lockfile_contents) { "--- {}\n" }

  def write_lockfile!
    allow(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", anything).and_call_original
    File.write("#{temp_dir}/.nandilock.yml", lockfile_contents)
  end

  describe ".file_present" do
    subject(:file_present) { described_class.file_present?(database) }

    context "lockfile exists" do
      before { write_lockfile! }

      it { expect(file_present).to eq(true) }
    end

    context "doesn't exist" do
      it { expect(file_present).to eq(false) }
    end
  end

  describe ".create" do
    subject(:create!) { described_class.create! }

    it "creates a file" do
      expect(File).to receive(:write).
        with("#{temp_dir}/.nandilock.yml", "--- {}\n").
        and_call_original

      create!
    end
  end

  describe ".add" do
    subject(:add) do
      described_class.add(
        file_name: "file_name",
        source_digest: "source_digest",
        compiled_digest: "compiled_digest",
        db_name: database,
      )
    end

    let(:lockfile_contents) { "--- {}\n" }

    before { write_lockfile! }

    it "adds the digests to the instance" do
      add

      expect(described_class.lockfiles[database]["file_name"][:source_digest]).
        to eq("source_digest")
      expect(described_class.lockfiles[database]["file_name"][:compiled_digest]).
        to eq("compiled_digest")
    end
  end

  describe ".get(file_name)" do
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
      expect(described_class.get(file_name: "migration1", db_name: database)).to eq(
        source_digest: "deadbeef1234",
        compiled_digest: "deadbeef5678",
      )
    end
  end

  describe ".persist!" do
    subject(:persist!) { described_class.persist! }

    let(:expected_yaml) do
      <<~YAML
        ---
        foo:
          bar: 5
      YAML
    end

    before do
      described_class.lockfiles[database] = {
        foo: {
          bar: 5,
        },
      }
    end

    it "writes the existing file" do
      expect(File).to receive(:write).with(
        "#{temp_dir}/.nandilock.yml",
        expected_yaml,
      )

      persist!
    end

    context "with multiple keys, not sorted by their SHA-256 hash" do
      let(:expected_yaml) do
        <<~YAML
          ---
          lower_hash:
            foo: 5
          higher_hash:
            foo: 5
        YAML
      end

      before do
        described_class.lockfiles[database] = {
          higher_hash: {
            foo: 5,
          },
          lower_hash: {
            foo: 5,
          },
        }
      end

      it "sorts the keys by their SHA-256 hash" do
        expect(File).to receive(:write).with(
          "#{temp_dir}/.nandilock.yml",
          expected_yaml,
        )

        persist!
      end
    end
  end

  describe "multi-database support" do
    let(:primary_db) { :primary }
    let(:analytics_db) { :analytics }

    before do
      # Clear all lockfiles for multi-db tests
      described_class.lockfiles.clear

      # Mock different lockfile paths for different databases
      allow(Nandi.config).to receive(:lockfile_path).with(primary_db).
        and_return("#{temp_dir}/.nandilock.yml")
      allow(Nandi.config).to receive(:lockfile_path).with(analytics_db).
        and_return("#{temp_dir}/.analytics_nandilock.yml")
    end

    describe ".file_present? with multiple databases" do
      it "checks correct file for each database" do
        # Create only primary lockfile
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")

        expect(described_class.file_present?(primary_db)).to be true
        expect(described_class.file_present?(analytics_db)).to be false
      end
    end

    describe ".create! with multiple databases" do
      it "creates separate lockfiles for different databases" do
        expect(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", "--- {}\n")
        expect(File).to receive(:write).with("#{temp_dir}/.analytics_nandilock.yml", "--- {}\n")

        described_class.create!(db_name: primary_db)
        described_class.create!(db_name: analytics_db)
      end

      it "does not re-create existing lockfiles" do
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")

        expect(File).to_not receive(:write).with("#{temp_dir}/.nandilock.yml", anything)

        described_class.create!(db_name: primary_db)
      end
    end

    describe ".add with multiple databases" do
      before do
        File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")
        File.write("#{temp_dir}/.analytics_nandilock.yml", "--- {}\n")
      end

      let(:add_migrations_to_databases) do
        described_class.add(
          file_name: "primary_migration",
          source_digest: "primary_source",
          compiled_digest: "primary_compiled",
          db_name: primary_db,
        )

        described_class.add(
          file_name: "analytics_migration",
          source_digest: "analytics_source",
          compiled_digest: "analytics_compiled",
          db_name: analytics_db,
        )
      end

      # rubocop: disable RSpec/ExampleLength
      it "adds migrations to correct database lockfile" do
        add_migrations_to_databases

        expect(described_class.lockfiles[primary_db]["primary_migration"][:source_digest]).
          to eq("primary_source")
        expect(described_class.lockfiles[analytics_db]["analytics_migration"][:source_digest]).
          to eq("analytics_source")
        expect(described_class.lockfiles[primary_db]["analytics_migration"]).to be_nil
        expect(described_class.lockfiles[analytics_db]["primary_migration"]).to be_nil
      end
      # rubocop: enable RSpec/ExampleLength
    end

    describe ".get with multiple databases" do
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
        primary_result = described_class.get(file_name: "shared_name", db_name: primary_db)
        analytics_result = described_class.get(file_name: "shared_name", db_name: analytics_db)

        expect(primary_result[:source_digest]).to eq("primary_digest")
        expect(analytics_result[:source_digest]).to eq("analytics_digest")
      end
    end

    describe ".persist! with multiple databases" do
      it "writes all database lockfiles" do
        described_class.lockfiles[primary_db] = { migration1: { foo: "bar" } }
        described_class.lockfiles[analytics_db] = { migration2: { baz: "qux" } }

        expect(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", anything)
        expect(File).to receive(:write).with("#{temp_dir}/.analytics_nandilock.yml", anything)

        described_class.persist!
      end
    end
  end

  describe "database validation and error handling" do
    describe "with invalid database configuration" do
      before do
        allow(Nandi.config).to receive(:lockfile_path).with(:invalid_db).and_call_original
      end

      it "propagates configuration errors" do
        expect { described_class.file_present?(:invalid_db) }.
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
        expect(described_class.file_present?(:test_db)).to be false
      end

      it "raises error on create! with missing directory" do
        expect { described_class.create!(db_name: :test_db) }.
          to raise_error(Errno::ENOENT)
      end
    end
  end

  describe "default database behavior" do
    let(:default_db_name) { :primary }
    let(:add_test_migration) do
      described_class.add(
        file_name: "test_migration",
        source_digest: "test_source",
        compiled_digest: "test_compiled",
      )
    end

    before do
      allow(Nandi.config).to receive(:default).
        and_return(instance_double(Nandi::MultiDatabase::Database, name: default_db_name))
      allow(Nandi.config).to receive(:lockfile_path).with(default_db_name).
        and_return("#{temp_dir}/.nandilock.yml")
    end

    it "uses default database when db_name not specified" do
      File.write("#{temp_dir}/.nandilock.yml", "--- {}\n")

      add_test_migration
      result = described_class.get(file_name: "test_migration")

      expect(result[:source_digest]).to eq("test_source")
      expect(described_class.lockfiles[default_db_name]).to_not be_nil
    end
  end
end
