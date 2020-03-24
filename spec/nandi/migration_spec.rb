# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/validator"

RSpec.describe Nandi::Migration do
  let(:validator) { Nandi::Validator }

  describe "name" do
    subject(:migration) { MyAmazingClass.new(validator).name }

    before do
      stub_const("MyAmazingClass", Class.new(described_class))
    end

    it { is_expected.to eq("MyAmazingClass") }
  end

  describe "#up and #down" do
    subject(:migration) { subject_class.new(validator) }

    context "with up but not down implemented" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end
        end
      end

      it "is valid" do
        result = migration.validate
        expect(result).to be_valid
      end
    end

    context "with down but not up implemented" do
      let(:subject_class) do
        Class.new(described_class) do
          def down; end
        end
      end

      it "is not valid" do
        result = migration.validate
        expect(result).to_not be_valid
      end
    end
  end

  describe "#add_index" do
    context "with one new index" do
      subject(:instructions) { subject_class.new(validator).up_instructions }

      context "with one indexed field" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, :foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:add_index)
        end
      end

      context "with more than one indexed field" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, %i[foo bar]
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:add_index)
        end
      end
    end

    context "with extra args" do
      subject(:instructions) { subject_class.new(validator).up_instructions }

      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_index :payments, :foo, extra: :arg
          end
        end
      end

      it "returns an instruction" do
        expect(instructions.first.procedure).to eq(:add_index)
      end
    end
  end

  describe "#remove_index" do
    subject(:instructions) { subject_class.new(validator).down_instructions }

    context "dropping an index by column name" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end

          def down
            remove_index :payments, :foo
          end
        end
      end

      it "returns an instruction" do
        expect(instructions.first.procedure).to eq(:remove_index)
      end
    end

    context "dropping an index by options hash" do
      context "with column property" do
        let(:subject_class) do
          Class.new(described_class) do
            def up; end

            def down
              remove_index :payments, column: :foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:remove_index)
        end
      end

      context "with name property" do
        let(:subject_class) do
          Class.new(described_class) do
            def up; end

            def down
              remove_index :payments, name: :index_payments_on_foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:remove_index)
        end
      end
    end
  end

  describe "#create_table" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          create_table :payments do |t|
            t.column :name, :string, default: "no one"
            t.column :amount, :float
            t.column :paid, :bool, default: false
            t.timestamps null: false
          end
        end
      end
    end

    let(:expected_columns) do
      [
        [:name, :string, { default: "no one" }],
        [:amount, :float, {}],
        [:paid, :bool, { default: false }],
      ]
    end

    it "returns an instruction" do
      expect(instructions.first.procedure).to eq(:create_table)
    end

    it "exposes the correct table name" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "exposes the correct columns number" do
      expect(instructions.first.columns.length).to eq(3)
    end

    it "exposes the correct columns values" do
      instructions.first.columns.each_with_index do |c, i|
        expect(c.name).to eq(expected_columns[i][0])
        expect(c.type).to eq(expected_columns[i][1])
        expect(c.args).to eq(expected_columns[i][2])
      end
    end

    it "exposes the args for timestamps" do
      expect(instructions.first.timestamps_args).to eq(null: false)
    end

    it "has no extra_args" do
      expect(instructions.first.extra_args).to eq(nil)
    end

    context "with extra args" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            create_table :payments, id: false do |t|
              t.column :name, :string, default: "no one"
              t.timestamps null: false
            end
          end
        end
      end

      let(:expected_columns) do
        [
          [:name, :string, { default: "no one" }],
        ]
      end

      it "returns an instruction" do
        expect(instructions.first.procedure).to eq(:create_table)
      end

      it "exposes the correct table name" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "exposes the correct columns number" do
        expect(instructions.first.columns.length).to eq(1)
      end

      it "exposes the correct columns values" do
        instructions.first.columns.each_with_index do |c, i|
          expect(c.name).to eq(expected_columns[i][0])
          expect(c.type).to eq(expected_columns[i][1])
          expect(c.args).to eq(expected_columns[i][2])
        end
      end

      it "exposes the args for timestamps" do
        expect(instructions.first.timestamps_args).to eq(null: false)
      end

      it "has extra_args" do
        expect(instructions.first.extra_args).to eq(id: false)
      end
    end

    context "type methods" do
      %i[
        bigint
        binary
        boolean
        date
        datetime
        decimal
        float
        integer
        json
        string
        text
        time
        timestamp
        virtual
        bigserial bit bit_varying box
        cidr circle citext
        daterange
        hstore
        inet int4range int8range interval
        jsonb
        line lseg ltree
        macaddr money
        numrange
        oid
        path point polygon primary_key
        serial
        tsrange tstzrange tsvector
        uuid
        xml
      ].each do |type|
        context type.to_s do
          let(:subject_class) do
            Class.new(described_class) do
              define_method :up do
                create_table :payments do |t|
                  t.send type, :name, null: true
                end
              end
            end
          end

          it "defines the type #{type}" do
            expect(instructions.first.columns.first.type).
              to eq(type)
          end
        end
      end
    end
  end

  describe "#drop_table" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          drop_table :payments
        end
      end
    end

    it "returns an instruction" do
      expect(instructions.first.procedure).to eq(:drop_table)
    end

    it "exposes the correct attributes" do
      expect(instructions.first.table).to eq(:payments)
    end
  end

  describe "#add_column" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "with no extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_column :payments, :my_column, :text
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_column)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct column name" do
        expect(instructions.first.name).to eq(:my_column)
      end

      it "has the correct column type" do
        expect(instructions.first.type).to eq(:text)
      end
    end

    context "with extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_column :payments, :my_column, :text, collate: :de_DE
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_column)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct column name" do
        expect(instructions.first.name).to eq(:my_column)
      end

      it "has the correct column type" do
        expect(instructions.first.type).to eq(:text)
      end

      it "sets the default constraints" do
        expect(instructions.first.extra_args).to eq(
          collate: :de_DE,
        )
      end
    end
  end

  describe "#add_reference" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "with no extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_reference :payments, :mandate
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_reference)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct ref name" do
        expect(instructions.first.ref_name).to eq(:mandate)
      end

      it "defaults index to false" do
        expect(instructions.first.extra_args).to eq(
          index: false,
        )
      end
    end

    context "with extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_reference :payments, :mandate, type: :text
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_reference)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct ref name" do
        expect(instructions.first.ref_name).to eq(:mandate)
      end

      it "forwards the extra options" do
        expect(instructions.first.extra_args).to eq(
          index: false,
          type: :text,
        )
      end
    end
  end

  describe "#remove_reference" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "with no extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            remove_reference :payments, :mandate
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:remove_reference)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct ref name" do
        expect(instructions.first.ref_name).to eq(:mandate)
      end
    end

    context "with extra options" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            remove_reference :payments, :mandate, index: true
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:remove_reference)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct ref name" do
        expect(instructions.first.ref_name).to eq(:mandate)
      end

      it "forwards the extra options" do
        expect(instructions.first.extra_args).to eq(
          index: true,
        )
      end
    end
  end

  describe "#remove_column" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "without extra args" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            remove_column :payments, :my_column
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:remove_column)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct column name" do
        expect(instructions.first.name).to eq(:my_column)
      end
    end

    context "with extra args" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            remove_column :payments, :my_column, cascade: true
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:remove_column)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct column name" do
        expect(instructions.first.name).to eq(:my_column)
      end

      it "has the correct extra_args" do
        expect(instructions.first.extra_args).to eq(
          cascade: true,
        )
      end
    end
  end

  describe "#add_foreign_key" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "with just table names" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_foreign_key :payments, :mandates
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_foreign_key)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct target" do
        expect(instructions.first.target).to eq(:mandates)
      end

      it "has the correct extra args" do
        expect(instructions.first.extra_args).to eq(
          validate: false,
          name: :payments_mandates_fk,
        )
      end
    end

    context "with constraint name" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_foreign_key :payments, :mandates, name: :zalgo_comes
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_foreign_key)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct target" do
        expect(instructions.first.target).to eq(:mandates)
      end

      it "has the correct extra args" do
        expect(instructions.first.extra_args).to eq(
          name: :zalgo_comes,
          validate: false,
        )
      end
    end

    context "with column name" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            add_foreign_key :payments, :mandates, column: :zalgo_comes
          end

          def down; end
        end
      end

      it "has the correct procedure" do
        expect(instructions.first.procedure).to eq(:add_foreign_key)
      end

      it "has the correct table" do
        expect(instructions.first.table).to eq(:payments)
      end

      it "has the correct target" do
        expect(instructions.first.target).to eq(:mandates)
      end

      it "has the correct extra args" do
        expect(instructions.first.extra_args).to eq(
          column: :zalgo_comes,
          name: :payments_mandates_fk,
          validate: false,
        )
      end
    end
  end

  describe "#add_check_constraint" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          add_check_constraint :payments, :check, "mandate_id IS NOT NULL"
        end

        def down; end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:add_check_constraint)
    end

    it "has the correct table" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "has the correct check" do
      expect(instructions.first.check).to eq("mandate_id IS NOT NULL")
    end

    it "has the correct name" do
      expect(instructions.first.name).to eq(:check)
    end
  end

  describe "#drop_constraint" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          drop_constraint :payments, :payments_mandates_fk
        end

        def down; end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:drop_constraint)
    end

    it "has the correct table" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "has the correct constraint name" do
      expect(instructions.first.name).to eq(:payments_mandates_fk)
    end
  end

  describe "#validate_constraint" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          validate_constraint :payments, :payments_mandates_fk
        end

        def down; end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:validate_constraint)
    end

    it "has the correct table" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "has the correct constraint name" do
      expect(instructions.first.name).to eq(:payments_mandates_fk)
    end

    it "has a low lock weight" do
      expect(instructions.first.lock).to eq(
        described_class::LockWeights::SHARE,
      )
    end
  end

  describe "#remove_not_null_constraint" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          remove_not_null_constraint :payments, :colour
        end

        def down; end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:remove_not_null_constraint)
    end

    it "has the correct table" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "has the correct column name" do
      expect(instructions.first.column).to eq(:colour)
    end
  end

  describe "#change_column_default" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          change_column_default :payments, :colour, "blue"
        end

        def down; end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:change_column_default)
    end

    it "has the correct table" do
      expect(instructions.first.table).to eq(:payments)
    end

    it "has the correct column name" do
      expect(instructions.first.column).to eq(:colour)
    end

    it "has the correct default value" do
      expect(instructions.first.value).to eq("blue")
    end
  end

  describe "#irreversible_migration" do
    subject(:instructions) { subject_class.new(validator).down_instructions }

    let(:subject_class) do
      Class.new(described_class) do
        def up
          remove_column :payments, :amount
        end

        def down
          irreversible_migration
        end
      end
    end

    it "has the correct procedure" do
      expect(instructions.first.procedure).to eq(:irreversible_migration)
    end

    it "has a low lock weight" do
      expect(instructions.first.lock).to eq(
        described_class::LockWeights::SHARE,
      )
    end
  end

  describe "syntax extensions" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    before do
      Nandi.configure do |c|
        c.register_method :new_method, extension
      end
    end

    after do
      Nandi.config.custom_methods.delete(:new_method)
    end

    let(:extension) do
      Struct.new(:foo, :bar) do
        def procedure
          :new_method
        end

        def lock
          Nandi::Migration::LockWeights::SHARE
        end
      end
    end

    let(:subject_class) do
      Class.new(described_class) do
        def up
          new_method :arg1, :arg2
        end
      end
    end

    it "creates an instance of the custom instruction" do
      expect(instructions.first).to be_a(extension)
    end

    it "passes the arguments to the constructor of the custom instruction" do
      instruction = instructions.first

      expect(instruction.foo).to eq(:arg1)
      expect(instruction.bar).to eq(:arg2)
    end
  end

  describe "timeouts" do
    subject(:migration) { subject_class.new(validator) }

    context "when the strictest lock is SHARE" do
      let(:subject_class) do
        Class.new(described_class) do
          def up
            validate_constraint :payments, :payments_mandates_fk
          end

          def down; end
        end
      end

      it "disables timeouts" do
        expect(migration.disable_lock_timeout?).to be(true)
        expect(migration.disable_statement_timeout?).to be(true)
      end

      context "and we have set a statement timeout" do
        let(:subject_class) do
          Class.new(described_class) do
            set_statement_timeout(10_000)

            def up
              validate_constraint :payments, :payments_mandates_fk
            end

            def down; end
          end
        end

        it "disables only the lock timeout" do
          expect(migration.disable_lock_timeout?).to be(true)
          expect(migration.disable_statement_timeout?).to be(false)
        end
      end

      context "and we have set a lock timeout" do
        let(:subject_class) do
          Class.new(described_class) do
            set_lock_timeout(10_000)

            def up
              validate_constraint :payments, :payments_mandates_fk
            end

            def down; end
          end
        end

        it "disables only the lock timeout" do
          expect(migration.disable_lock_timeout?).to be(false)
          expect(migration.disable_statement_timeout?).to be(true)
        end
      end
    end
  end
end
