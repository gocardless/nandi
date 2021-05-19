# frozen_string_literal: true

RSpec.describe Nandi::Lockfile do
  before do
    allow(Nandi.config).to receive(:lockfile_directory).and_return("db")
    allow(File).to receive(:read).
      with("db/.nandilock.yml").and_return("")

    described_class.lockfile = nil
  end

  describe ".file_present" do
    subject(:file_present) { described_class.file_present? }

    context "lockfile exists" do
      before { allow(File).to receive(:exist?).and_return(true) }

      it { expect(file_present).to eq(true) }
    end

    context "doesn't exist" do
      before { allow(File).to receive(:exist?).and_return(false) }

      it { expect(file_present).to eq(false) }
    end
  end

  describe ".create" do
    subject(:create!) { described_class.create! }

    before { allow(File).to receive(:exist?).and_return(false) }

    it "creates a file" do
      expect(File).to receive(:write).
        with("db/.nandilock.yml", "--- {}\n")

      create!
    end
  end

  describe ".add" do
    subject(:add) do
      described_class.add(
        file_name: "file_name",
        source_digest: "source_digest",
        compiled_digest: "compiled_digest",
      )
    end

    let(:lockfile) { "--- {}\n" }

    before do
      allow(File).to receive(:write).with("db/.nandilock.yml", kind_of(String))
      allow(File).to receive(:read).with("db/.nandilock.yml").
        and_return(lockfile)
    end

    it "adds the digests to the instance" do
      add

      expect(described_class.lockfile["file_name"][:source_digest]).
        to eq("source_digest")
      expect(described_class.lockfile["file_name"][:compiled_digest]).
        to eq("compiled_digest")
    end
  end

  describe ".get(file_name)" do
    let(:lockfile) do
      <<~YAML
        ---
        migration1:
          source_digest: "deadbeef1234"
          compiled_digest: "deadbeef5678"
      YAML
    end

    before do
      allow(File).to receive(:write).with("db/.nandilock.yml", kind_of(String))
      allow(File).to receive(:read).with("db/.nandilock.yml").
        and_return(lockfile)
    end

    it "retrieves the digests" do
      expect(described_class.get("migration1")).to eq(
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
      described_class.lockfile = {
        foo: {
          bar: 5,
        },
      }
    end

    it "writes the existing file" do
      expect(File).to receive(:write).with(
        "db/.nandilock.yml",
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
        described_class.lockfile = {
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
          "db/.nandilock.yml",
          expected_yaml,
        )

        persist!
      end
    end
  end
end
