# frozen_string_literal: true

require "digest"
require "nandi/migration"

RSpec.describe Nandi::CompiledMigration do
  let(:renderer) do
    Class.new(Object) do
      def self.generate(migration); end
    end
  end

  let(:base_path) do
    File.join(
      File.dirname(__FILE__),
      "/fixtures/example_migrations",
    )
  end

  let(:valid_migration) { "#{base_path}/20180104120000_my_migration.rb" }
  let(:invalid_migration) { "#{base_path}/20180104120000_my_invalid_migration.rb" }
  let(:invalid_index_migration) do
    "#{base_path}/20180104120000_my_invalid_index_migration.rb"
  end

  let(:source_contents) { "source_migration" }
  let(:compiled_contents) { "compiled_migration" }

  let(:expected_source_digest) { Digest::SHA256.hexdigest(source_contents) }
  let(:expected_compiled_digest) { Digest::SHA256.hexdigest(compiled_contents) }

  let(:lockfile) do
    lockfile_contents = {
      "20180104120000_my_migration.rb".to_sym => {
        source_digest: expected_source_digest,
        compiled_digest: expected_compiled_digest,
      },
    }

    StringIO.new(lockfile_contents.deep_stringify_keys.to_yaml)
  end

  let(:file) { valid_migration }

  before do
    allow(File).to receive(:read).with(Nandi::Lockfile.path).and_return(lockfile)
    allow(File).to receive(:write).with(Nandi::Lockfile.path).and_return(lockfile)

    Nandi.configure do |config|
      config.renderer = renderer
    end
  end

  describe "#body" do
    subject(:body) { described_class.new(file).body }

    context "when the migration has changed" do
      let(:file) { valid_migration }
      let(:source_contents) { "contents_changed" }

      it "compiles the migration" do
        expect(renderer).to receive(:generate) do |migration|
          expect(migration).to be_a(Nandi::Migration)
          expect(migration.name).to eq("MyMigration")
        end

        body
      end
    end

    context "invalid migration" do
      let(:file) { invalid_migration }

      it "raises an InvalidMigrationError" do
        expect { body }.to raise_error(
          described_class::InvalidMigrationError,
          /creating more than one index per migration/,
        )
      end
    end

    context "invalid index migration" do
      let(:file) { invalid_index_migration }

      it "raises an InvalidMigrationError" do
        expect { body }.to raise_error(
          described_class::InvalidMigrationError,
          /add_index: index type can only be one of \[:btree, :hash, :brin\]/,
        )
      end
    end

    context "when both migrations are unchanged" do
      let(:file) { valid_migration }

      it "doesn't compile the migration" do
        expect(renderer).to_not receive(:generate)
      end
    end
  end

  describe "#output_path" do
    subject(:output_path) { described_class.new(file).output_path }

    it "has an output path" do
      expect(output_path).to eq("db/migrate/#{File.basename(file)}")
    end
  end

  describe "#compiled_digest" do
    subject(:compiled_digest) { described_class.new(file).compiled_digest }

    it "returns the digest of the compiled migration" do
      allow_any_instance_of(described_class).to receive(:body).
        and_return(compiled_contents)

      expect(compiled_digest).to eq(expected_compiled_digest)
    end
  end

  describe "#source_digest" do
    subject(:source_digest) { described_class.new(file).source_digest }

    it "returns the digest of the source migration" do
      allow(File).to receive(:read).and_return(source_contents)
      expect(source_digest).to eq(expected_source_digest)
    end
  end
end
