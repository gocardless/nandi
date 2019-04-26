# frozen_string_literal: true

require "spec_helper"
require "nandi/renderers/active_record"
require "nandi/migration"
require "nandi/validator"
require "pry"

RSpec.describe Nandi::Renderers::ActiveRecord do
  describe "::generate" do
    subject(:migration) do
      described_class.generate(safe_migration.new(Nandi::Validator))
    end

    let(:fixture_root) do
      File.join(
        File.dirname(__FILE__),
        "../fixtures/rendered/active_record",
      )
    end

    describe "adding and dropping an index" do
      let(:fixture) do
        File.read(File.join(fixture_root, "create_and_drop_index.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            create_index :payments, %i[foo bar]
          end

          def down
            drop_index :payments, %i[foo bar]
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end
  end
end
