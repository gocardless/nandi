# frozen_string_literal: true

require "tempfile"

RSpec.describe Nandi::Lockfile do
  before do
    allow(Nandi.config).to receive(:lockfile_directory).and_return(temp_dir)
    described_class.lockfile = nil
  end

  let(:temp_dir) { Dir.mktmpdir }
  let(:lockfile_contents) { "--- {}\n" }

  def write_lockfile!
    allow(File).to receive(:write).with("#{temp_dir}/.nandilock.yml", anything).and_call_original
    File.write("#{temp_dir}/.nandilock.yml", lockfile_contents)
  end

  describe ".file_present" do
    subject(:file_present) { described_class.file_present? }

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
      )
    end

    let(:lockfile_contents) { "--- {}\n" }

    before { write_lockfile! }

    it "adds the digests to the instance" do
      add

      expect(described_class.lockfile["file_name"][:source_digest]).
        to eq("source_digest")
      expect(described_class.lockfile["file_name"][:compiled_digest]).
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
          "#{temp_dir}/.nandilock.yml",
          expected_yaml,
        )

        persist!
      end
    end
  end
end
