# frozen_string_literal: true

require "nandi/safe_migration_enforcer"

RSpec.describe Nandi::SafeMigrationEnforcer do
  subject(:enforcer) { described_class.new }

  let(:safe_migration_dir) { Nandi::SafeMigrationEnforcer::SAFE_MIGRATION_DIR }
  let(:ar_migration_dir) { Nandi::SafeMigrationEnforcer::AR_MIGRATION_DIR }

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

  before do
    safe_migration_glob = File.join(safe_migration_dir, "*.rb")
    ar_migration_glob = File.join(ar_migration_dir, "*.rb")

    allow(Dir).to receive(:glob).with(safe_migration_glob).
      and_return(safe_migration_files)
    allow(Dir).to receive(:glob).with(ar_migration_glob).
      and_return(ar_migration_files)

    allow(File).to receive(:exist?).with(".nandiignore").and_return(false)
    allow(File).to receive(:read).with(%r{db/migrate}).and_return("generated_content")

    allow(Rails::Generators).to receive(:invoke).with("nandi:compile")
  end

  describe "#run" do
    context "when there are no files" do
      let(:safe_migration_files) { [] }
      let(:ar_migration_files) { [] }

      it "returns true" do
        expect(enforcer.run).to eq(true)
      end
    end

    context "when all safe migrations and generated ActiveRecord migrations match" do
      it "returns true" do
        expect(enforcer.run).to eq(true)
      end
    end

    context "when a generated ActiveRecord migration is missing" do
      before do
        ar_migration_files.shift
      end

      it "raises an error with an appropriate message" do
        expect { enforcer.run }.to raise_error(
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
        expect { enforcer.run }.to raise_error(
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

      it "raises an error with an appropriate message" do
        expect(Rails::Generators).to receive(:invoke).with("nandi:compile")

        expect { enforcer.run }.to raise_error do |err|
          expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)
          expect(err.message).
            to match(/20190513163422_add_elephants.rb.*Please don't hand-edit/m)
          expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
        end
      end
    end

    context "with a .nandiignore file that allows some handwritten migrations" do
      before do
        allow(File).to receive(:exist?).with(".nandiignore").and_return(true)

        content = ar_migration_files[0..1].join("\n")
        allow(File).to receive(:read).with(".nandiignore").and_return(content)
      end

      context "and handwritten migrations that are specified in the file" do
        before do
          safe_migration_files.shift(2)
        end

        it "returns true" do
          expect(enforcer.run).to eq(true)
        end
      end

      context "and a handwritten migration that isn't specified in the file" do
        before do
          safe_migration_files.shift(3)
        end

        it "returns true" do
          expect { enforcer.run }.to raise_error do |err|
            expect(err.class).to eq(Nandi::SafeMigrationEnforcer::MigrationLintingFailed)

            expect(err.message).to match(/20190513163424_add_zoos.rb.*Please use Nandi/m)
            expect(err.message).to_not match(/20190513163422_add_elephants.rb/)
            expect(err.message).to_not match(/20190513163423_add_beachballs.rb/)
          end
        end
      end
    end
  end
end
