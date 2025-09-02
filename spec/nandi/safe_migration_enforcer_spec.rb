# frozen_string_literal: true

require "nandi/safe_migration_enforcer"

RSpec.shared_examples "linting" do
  let(:db_name) { nil } # Test default single-database behavior

  context "when there are no files" do
    let(:safe_migrations) { [] }
    let(:ar_migrations) { [] }

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
      ar_migrations.shift
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
      safe_migrations.shift
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error(
        Nandi::SafeMigrationEnforcer::MigrationLintingFailed,
        /20190513163422_add_elephants.rb.*Please use Nandi/m,
      )
    end
  end

  context "when a safe migration has had its content altered" do
    let(:altered_migration) { safe_migrations.first }

    before do
      allow(File).to receive(:read).with(kind_of(String)).
        and_return("generated_content")
      allow(File).to receive(:read).
        with(Regexp.new("#{safe_migration_dir}/#{altered_migration}")).
        and_return("newer_content")
      allow(File).to receive(:read).with(Nandi::Lockfile.path(db_name)).and_return(lockfile)
      allow(File).to receive(:write).with(Nandi::Lockfile.path(db_name), kind_of(String)).
        and_return(lockfile)
    end

    # rubocop:disable RSpec/ExampleLength
    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error do |err|
        expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
        expect(err.message).
          to match(
            /20190513163422_add_elephants.rb.*Please recompile your migrations/m,
          )
        expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end

  context "when a generated migration has had its content altered" do
    let(:altered_migration) { ar_migrations.first }

    before do
      allow(File).to receive(:read).with(kind_of(String)).
        and_return("generated_content")
      allow(File).to receive(:read).
        with(Regexp.new("#{ar_migration_dir}/#{altered_migration}")).
        and_return("hand_edited_content")
      allow(File).to receive(:read).with(Nandi::Lockfile.path(db_name)).and_return(lockfile)
      allow(File).to receive(:write).with(Nandi::Lockfile.path(db_name), kind_of(String)).
        and_return(lockfile)
    end

    it "raises an error with an appropriate message" do
      expect { subject.run }.to raise_error do |err|
        expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
        expect(err.message).
          to match(/20190513163422_add_elephants.rb.*Please don't hand-edit/m)
        expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
      end
    end
  end
end

RSpec.describe Nandi::SafeMigrationEnforcer do
  subject { described_class.new }

  let(:safe_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_SAFE_MIGRATION_DIR }
  let(:ar_migration_dir) { Nandi::SafeMigrationEnforcer::DEFAULT_AR_MIGRATION_DIR }

  let(:safe_migrations) do
    [
      "20190513163422_add_elephants.rb",
      "20190513163423_add_beachballs.rb",
      "20190513163424_add_zoos.rb",
    ]
  end
  let(:ar_migrations) do
    [
      "20190513163422_add_elephants.rb",
      "20190513163423_add_beachballs.rb",
      "20190513163424_add_zoos.rb",
    ]
  end

  let(:ar_migration_paths) { ar_migrations.map { |f| File.join(ar_migration_dir, f) } }

  let(:lockfile) do
    lockfile_contents = ar_migration_paths.each_with_object({}) do |ar_file, hash|
      file_name = File.basename(ar_file)

      hash[file_name] = {
        source_digest: Digest::SHA256.hexdigest("generated_content"),
        compiled_digest: Digest::SHA256.hexdigest("generated_content"),
      }
    end

    lockfile_contents.with_indifferent_access
  end

  before do
    allow_any_instance_of(described_class).
      to receive(:matching_migrations).
      with(safe_migration_dir).
      and_return(safe_migrations)

    allow_any_instance_of(described_class).
      to receive(:matching_migrations).
      with(ar_migration_dir).
      and_return(ar_migrations)

    Nandi::Lockfile.lockfiles[:primary] = lockfile # Test default single-database behavior

    allow(Nandi::Lockfile).to receive(:persist)

    allow(File).to receive(:read).with(Regexp.new(safe_migration_dir)).
      and_return("generated_content")

    allow(File).to receive(:read).with(Regexp.new(ar_migration_dir)).
      and_return("generated_content")
  end

  describe "#run" do
    context "with the default migration directories" do
      it_behaves_like "linting"
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

      it_behaves_like "linting"
    end
  end
end
