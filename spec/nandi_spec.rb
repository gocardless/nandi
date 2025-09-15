# frozen_string_literal: true

require "nandi/migration"

RSpec.describe Nandi do
  let(:renderer) do
    Class.new(Object) do
      def self.generate(migration); end
    end
  end

  before do
    # Test default single-database behavior
    allow_any_instance_of(Nandi::Lockfile).to receive(:persist!)
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

    before do
      described_class.configure do |config|
        config.renderer = renderer
        config.migration_directory = base_path
      end
    end

    context "with a valid migration" do
      let(:files) { ["20180104120000_my_migration.rb"] }

      it "yields output" do
        allow(renderer).to receive(:generate).and_return("output")

        described_class.compile(**args) do |output|
          expect(output.first.file_name).to eq("20180104120000_my_migration.rb")
          expect(output.first.body).to eq("output")
        end
      end
    end

    context "with a post-processing step" do
      let(:files) { ["20180104120000_my_migration.rb"] }

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

        described_class.compile(**args) do |output|
          expect(output.first.file_name).to eq("20180104120000_my_migration.rb")
          expect(output.first.body).to eq("processed output")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
