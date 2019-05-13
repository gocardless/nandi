# frozen_string_literal: true

require "spec_helper"
require "nandi/renderers/active_record"
require "nandi/migration"
require "nandi/validator"

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

      context "with custom timeouts" do
        let(:fixture) do
          File.read(File.join(fixture_root, "create_and_drop_index_timeouts.rb"))
        end

        let(:safe_migration) do
          Class.new(Nandi::Migration) do
            set_statement_timeout(5000)
            set_lock_timeout(5000)

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

    describe "creating and dropping a table" do
      let(:fixture) do
        File.read(File.join(fixture_root, "create_and_drop_table.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            create_table :payments do |t|
              t.column :payer, :string
              t.column :ammount, :float
              t.column :payed, :bool, default: false
            end
          end

          def down
            drop_table :payments
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "adding and dropping an column" do
      let(:fixture) do
        File.read(File.join(fixture_root, "create_and_drop_column.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_column :payments, :foo, :text, collate: :de_DE
          end

          def down
            drop_column :payments, :foo, cascade: true
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#alter_column" do
      let(:fixture) do
        File.read(File.join(fixture_root, "alter_column.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            alter_column :payments, :foo, null: true
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end
  end
end
