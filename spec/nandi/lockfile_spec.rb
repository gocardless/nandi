RSpec.describe Nandi::Lockfile do
  before do
    allow(File).to receive(:read).with(Pathname.new(".nandilock.yml")).and_return("")
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
    subject(:create) { described_class.create }

    it "creates a file" do
      expect(File).to receive(:create).with(".nandilock.yml")

      create
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

    it "adds the digests to the instance" do
      add

      expect(described_class.lockfile["file_name"][:source_digest]).
        to eq("source_digest")
      expect(described_class.lockfile["file_name"][:compiled_digest]).
        to eq("compiled_digest")
    end
  end

  describe ".get(file_name)" do
    it "does something" do
      expect().to
    end

  end

  describe ".load!" do
    it "does something" do
      expect().to
    end

  end

  describe ".persist!" do
    it "does something" do
      expect().to
    end

  end

  describe ".path" do
    it "does something" do
      expect().to
    end

  end

end