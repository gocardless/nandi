# frozen_string_literal: true

require "nandi/safe_migration_enforcer"

RSpec.shared_examples "linting" do
  context "when there are no files" do
    let(:safe_migration_files) { [] }
    let(:ar_migration_files) { [] }

    it "returns true" do
      expect(subject.run).to eq(true)
    end
  end

  context "when all safe migrations and generated ActiveRecord migrations match" do
    it "returns true" do
      expect(subject.run).to eq(true)
    end
  end

  context "when a generated ActiveRecord migration is missing" do
    before do
      ar_migration_files.shift
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error(
        Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        /pending generation.*20190513163422_add_elephants.rb/m,
      )
    end
  end

  context "when an ActiveRecord migration has been written rather than generated" do
    before do
      safe_migration_files.shift
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error(
        Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        /20190513163422_add_elephants.rb.*Please use Nandi/m,
      )
    end
  end

  context "when a generated migration has had its content altered" do
    let(:altered_migration) { ar_migration_files.first }

    before do
      allow(File).to receive(:read).with(altered_migration).and_return(
        "hand_edited_content",
        "generated_content",
      )
    end

    # rubocop:disable RSpec/ExampleLength
    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error do |err|
        expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
        expect(err.message).
          to match(/20190513163422_add_elephants.rb.*Please don't hand-edit/m)
        expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end

  context "with a .nandiignore file that allows some handwritten migrations" do
    let(:ignored_files) { ar_migration_files[0..1] }

    context "and handwritten migrations that are specified in the file" do
      before do
        safe_migration_files.shift(2)
      end

      it "returns true" do
        expect(subject.run).to eq(true)
      end
    end

    context "and a handwritten migration that isn't specified in the file" do
      before do
        safe_migration_files.shift(3)
      end

      it "returns true" do
        expect { subject.run }.to raise_error do |err|
          expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)

          expect(err.message).to match(/20190513163424_add_zoos.rb.*Please use Nandi/m)
          expect(err.message).to_not match(/20190513163422_add_elephants.rb/)
          expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
        end
      end
    end
  end
end

RSpec.describe Nandi::SafeMigrationEnforcer do
  subject { described_class.new }

  let(:safe_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_SAFE_MIGRATION_DIR }
  let(:ar_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_AR_MIGRATION_DIR }

  let(:safe_migration_files) do
    [
      File.join(safe_migration_dir, "20190513163422_add_elephants.rb"),
      File.join(safe_migration_dir, "20190513163423_add_beachballs.rb"),
      File.join(safe_migration_dir, "20190513163424_add_zoos.rb"),
    ]
  end
  let(:ar_migration_files) do
    [
      File.join(ar_migration_dir, "20190513163422_add_elephants.rb"),
      File.join(ar_migration_dir, "20190513163423_add_beachballs.rb"),
      File.join(ar_migration_dir, "20190513163424_add_zoos.rb"),
    ]
  end

  let(:ignored_files) { [] }
  let(:lockfile) do
    lockfile_contents = ar_migration_files.each_with_object({}) do |ar_file, hash|
      file_name = File.basename(ar_file)

      hash[file_name] = {
        source_digest: Digest::SHA256.hexdigest("generated_content"),
        compiled_digest: Digest::SHA256.hexdigest("generated_content"),
      }
    end

    StringIO.new(lockfile_contents.deep_stringify_keys.to_yaml)
  end

  before do
    safe_migration_glob = File.join(safe_migration_dir, "*.rb")
    ar_migration_glob = File.join(ar_migration_dir, "*.rb")

    allow(Dir).to receive(:glob).with(safe_migration_glob).
      and_return(safe_migration_files)
    allow(Dir).to receive(:glob).with(ar_migration_glob).
      and_return(ar_migration_files)

    allow(File).to receive(:read).with(Nandi::Lockfile.path).and_return(lockfile)
    allow(File).to receive(:write).with(Nandi::Lockfile.path).and_return(lockfile)

    allow(File).to receive(:read).with(Regexp.new(ar_migration_dir)).
      and_return("generated_content")

    allow(Nandi).to receive(:ignored_files).and_return(ignored_files)
  end

  describe "#run" do
    context "with the default migration directories" do
      include_examples "linting"
    end

    context "with custom migration directories" do
      subject do
        described_class.new(
          safe_migration_dir: safe_migration_dir,
          ar_migration_dir: ar_migration_dir,
        )
      end

      let(:safe_migration_dir) { "custom/safe/migration/dir" }
      let(:ar_migration_dir) { "custom/ar/migration/dir" }

      include_examples "linting"
    end
  end
end
