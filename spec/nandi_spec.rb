# frozen_string_literal: true

require "nandi/migration"

RSpec.describe Nandi do
  let(:renderer) do
    Class.new(Object) do
      def self.generate(migration); end
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

    before do
      described_class.configure do |config|
        config.renderer = renderer
      end
    end

    context "with a valid migration" do
      let(:files) { ["#{base_path}/20180104120000_my_migration.rb"] }

      it "calls the generator with the correct migration class" do
        expect(renderer).to receive(:generate) do |migration|
          expect(migration).to be_a(Nandi::Migration)
          expect(migration.name).to eq("MyMigration")
        end

        described_class.compile(args) { |_| nil }
      end

      it "yields output" do
        expect(renderer).to receive(:generate).and_return("output")

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
        end.to raise_error(described_class::InvalidMigrationError)
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
