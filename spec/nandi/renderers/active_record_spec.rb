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
            add_index :payments, %i[foo bar]
          end

          def down
            remove_index :payments, %i[foo bar]
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
              add_index :payments, %i[foo bar]
            end

            def down
              remove_index :payments, %i[foo bar]
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

      context "with timestamps with args" do
        let(:fixture) do
          File.read(File.join(fixture_root, "create_and_drop_table_with_timestamps.rb"))
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
                t.timestamps null: false
              end
            end

            def down
              drop_table :payments
            end
          end
        end

        it { is_expected.to eq(fixture) }
      end

      context "with extra args" do
        let(:fixture) do
          File.read(File.join(fixture_root, "create_and_drop_table_with_extra_args.rb"))
        end

        let(:safe_migration) do
          Class.new(Nandi::Migration) do
            def self.name
              "MyAwesomeMigration"
            end

            def up
              create_table :payments, id: false, force: true do |t|
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

      context "with timestamps without args" do
        let(:fixture) do
          File.read(
            File.join(
              fixture_root,
              "create_and_drop_table_with_timestamps_and_not_args.rb",
            ),
          )
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
                t.timestamps
              end
            end

            def down
              drop_table :payments
            end
          end
        end

        it { is_expected.to eq(fixture) }
      end
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
            remove_column :payments, :foo, cascade: true
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "adding and dropping an reference" do
      let(:fixture) do
        File.read(File.join(fixture_root, "create_and_drop_reference.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_reference :payments, :mandate, type: :text
          end

          def down
            remove_reference :payments, :mandate
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#add_foreign_key" do
      let(:fixture) do
        File.read(File.join(fixture_root, "add_foreign_key.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_foreign_key :payments, :mandates, column: :zalgo_comes
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#add_check_constraint" do
      let(:fixture) do
        File.read(File.join(fixture_root, "add_check_constraint.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            add_check_constraint :payments, :check, "foo IS NOT NULL"
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#change_column_default" do
      let(:fixture) do
        File.read(File.join(fixture_root, "change_column_default.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            change_column_default :payments, :colour, "blue"
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#validate_constraint" do
      let(:fixture) do
        File.read(File.join(fixture_root, "validate_constraint.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            validate_constraint :payments, :payments_mandates_fk
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#drop_constraint" do
      let(:fixture) do
        File.read(File.join(fixture_root, "drop_constraint.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            drop_constraint :payments, :payments_mandates_fk
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#remove_not_null_constraint" do
      let(:fixture) do
        File.read(File.join(fixture_root, "remove_not_null_constraint.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            remove_not_null_constraint :payments, :colours
          end

          def down; end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "#irreversible_migration" do
      let(:fixture) do
        File.read(File.join(fixture_root, "irreversible_migration.rb"))
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            remove_column :payments, :amount
          end

          def down
            irreversible_migration
          end
        end
      end

      it { is_expected.to eq(fixture) }
    end

    describe "custom instructions" do
      let(:fixture) do
        File.read(File.join(fixture_root, "custom_instruction.rb"))
      end

      let(:extension) do
        Struct.new(:foo, :bar) do
          def procedure
            :new_method
          end

          def template
            Class.new(Cell::ViewModel) do
              def show
                "new_method"
              end
            end
          end

          def lock
            Nandi::Migration::LockWeights::SHARE
          end
        end
      end

      let(:safe_migration) do
        Class.new(Nandi::Migration) do
          def self.name
            "MyAwesomeMigration"
          end

          def up
            new_method :arg1, :arg2
          end

          def down; end
        end
      end

      before do
        Nandi.configure do |c|
          c.register_method :new_method, extension
        end
      end

      after do
        Nandi.config.custom_methods.delete(:new_method)
      end

      it { is_expected.to eq(fixture) }

      context "with a mixin" do
        let(:fixture) do
          File.read(File.join(fixture_root, "custom_instruction_with_mixins.rb"))
        end

        let(:extension) do
          Struct.new(:foo, :bar) do
            def procedure
              :new_method
            end

            def mixins
              [
                Class.new do
                  def self.name
                    "My::Important::Mixin"
                  end
                end,
                Class.new do
                  def self.name
                    "My::Other::Mixin"
                  end
                end,
              ]
            end

            def template
              Class.new(Cell::ViewModel) do
                def show
                  "new_method"
                end
              end
            end

            def lock
              Nandi::Migration::LockWeights::SHARE
            end
          end
        end

        let(:safe_migration) do
          Class.new(Nandi::Migration) do
            def self.name
              "MyAwesomeMigration"
            end

            def up
              new_method :arg1, :arg2
            end

            def down; end
          end
        end

        before do
          Nandi.configure do |c|
            c.register_method :new_method, extension
          end
        end

        after do
          Nandi.config.custom_methods.delete(:new_method)
        end

        it { is_expected.to eq(fixture) }
      end

      context "with a block argument" do
        let(:fixture) do
          File.read(File.join(fixture_root, "custom_instruction_with_block.rb"))
        end

        let(:extension) do
          Class.new do
            def procedure
              :new_method
            end

            def initialize
              @block_result = yield
            end

            attr_reader :block_result

            def lock
              Nandi::Migration::LockWeights::SHARE
            end

            def template
              Class.new(Cell::ViewModel) do
                property :block_result

                def show
                  "new_method #{block_result}"
                end
              end
            end
          end
        end

        let(:safe_migration) do
          Class.new(Nandi::Migration) do
            def self.name
              "MyAwesomeMigration"
            end

            def up
              new_method { "block rockin' beats" }
            end

            def down; end
          end
        end

        before do
          Nandi.configure do |c|
            c.register_method :new_method, extension
          end
        end

        after do
          Nandi.config.custom_methods.delete(:new_method)
        end

        it { is_expected.to eq(fixture) }
      end
    end
  end
end
