# frozen_string_literal: true

require "nandi/migration"

RSpec.describe Nandi do
  let(:renderer) do
    Class.new(Object) do
      def self.generate(migration); end
    end
  end

  before do
    Nandi::Lockfile.lockfile = {}
    allow(Nandi::Lockfile).to receive(:persist!)
  end

  describe "::ignored_files" do
    subject(:files) { described_class.ignored_files }

    before { described_class.instance_variable_set(:@ignored_files, nil) }

    context "with no .nandiignore" do
      before do
        allow(File).to receive(:exist?).with(".nandiignore").
          and_return(false)
      end

      it { is_expected.to eq([]) }
    end

    context "with no .nandiignore" do
      before do
        allow(File).to receive(:exist?).with(".nandiignore").
          and_return(true)

        allow(File).to receive(:read).with(".nandiignore").
          and_return(["db/migrate/thing1.rb", "db/migrate/thing2.rb"].join("\n"))
      end

      it { is_expected.to eq(["db/migrate/thing1.rb", "db/migrate/thing2.rb"]) }
    end
  end

  describe "::ignored_filenames" do
    subject(:files) { described_class.ignored_filenames }

    before { described_class.instance_variable_set(:@ignored_files, nil) }

    context "with no .nandiignore" do
      before do
        allow(File).to receive(:exist?).with(".nandiignore").
          and_return(false)
      end

      it { is_expected.to eq([]) }
    end

    context "with no .nandiignore" do
      before do
        allow(File).to receive(:exist?).with(".nandiignore").
          and_return(true)

        allow(File).to receive(:read).with(".nandiignore").
          and_return(["db/migrate/thing1.rb", "db/migrate/thing2.rb"].join("\n"))
      end

      it { is_expected.to eq(["thing1.rb", "thing2.rb"]) }
    end
  end

  describe "::compile" do
    let(:args) do
      {
        files: files,
      }
    end

    let(:base_path) do
      File.join(
        File.dirname(__FILE__),
        "/nandi/fixtures/example_migrations",
      )
    end

    let(:ignored_files) { [] }

    before do
      allow(described_class).to receive(:ignored_files).
        and_return(ignored_files)
      described_class.configure do |config|
        config.renderer = renderer
      end
    end

    context "with a valid migration" do
      let(:files) { ["#{base_path}/20180104120000_my_migration.rb"] }

      it "yields output" do
        allow(renderer).to receive(:generate).and_return("output")

        described_class.compile(args) do |output|
          expect(output.first.file_name).to eq("20180104120000_my_migration.rb")
          expect(output.first.body).to eq("output")
        end
      end
    end

    context "with an invalid migration" do
      let(:files) { ["#{base_path}/20180104120000_my_invalid_migration.rb"] }

      it "throws an invalid migration error" do
        expect do
          described_class.compile(args) { |_| nil }
        end.to raise_error(
          Nandi::CompiledMigration::InvalidMigrationError,
          /creating more than one index per migration/,
        )
      end
    end

    context "with an ignored migration" do
      let(:files) { ["#{base_path}/20180104120000_my_migration.rb"] }
      let(:ignored_files) { files }

      it "does not compile the migration" do
        expect(renderer).to_not receive(:generate)

        described_class.compile(args) do |output|
          expect(output).to eq([])
        end
      end
    end

    context "with a post-processing step" do
      let(:files) { ["#{base_path}/20180104120000_my_migration.rb"] }

      before do
        allow(renderer).to receive(:generate).and_return("output")
      end

      # rubocop:disable RSpec/ExampleLength
      it "yields processed output" do
        described_class.configure do |config|
          config.post_process do |arg|
            expect(arg).to eq("output")

            "processed output"
          end
        end

        described_class.compile(args) do |output|
          expect(output.first.file_name).to eq("20180104120000_my_migration.rb")
          expect(output.first.body).to eq("processed output")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
