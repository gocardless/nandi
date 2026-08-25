# frozen_string_literal: true

require "spec_helper"
require "nandi/renderers/renderer"
require "nandi/migration"
require "nandi/yugabyte/nandi/migration/yugabyte"
require "nandi/validator"

RSpec.describe Nandi::Renderers::ActiveRecordYugabyte::Generate do
  describe "#generate" do
    subject(:migration) do
      described_class.call(safe_migration.new(Nandi::Validator))
    end

    let(:fixture_root) do
      File.join(
        File.dirname(__FILE__),
        "../../../../fixtures/rendered/active_record",
      )
    end

    let(:current_rails_version) do
      ActiveRecord::Migration.current_version
    end

    def normalize_fixture(content)
      content.gsub(/ActiveRecord::Migration\[\d+\.\d+\]/, "ActiveRecord::Migration[#{current_rails_version}]")
    end

    describe "adding a yugabyte-specific index" do
      let(:fixture) do
        normalize_fixture(File.read(File.join(fixture_root, "create_and_drop_index_new.rb")))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration::Yugabyte) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_index :payments, %i[foo bar], bucket_on: :id, bucket_count: 16
          end

          def down
            remove_index :payments, %i[foo bar]
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "adding a standard index with no yugabyte-specific options" do
      let(:fixture) do
        normalize_fixture(File.read(File.join(fixture_root, "create_and_drop_index.rb")))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration::Yugabyte) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_index :payments, %i[foo bar]
          end

          def down
            remove_index :payments, %i[foo bar]
          end
        end
      end

      it "renders the same as the default ActiveRecord add_index" do
        expect(migration).to eq(fixture)
      end
    end
  end
end
