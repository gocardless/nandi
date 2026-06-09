# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/add_foreign_key"
require "nandi/instructions/create_table"
require "nandi/migration_modifiers/create_table_validates_fks"

RSpec.describe Nandi::MigrationModifiers::CreateTableValidatesFks do
  def fk(table:, target: :mandates)
    Nandi::Instructions::AddForeignKey.new(table: table, target: target)
  end

  def create_table(table)
    Nandi::Instructions::CreateTable.new(table: table, columns_block: proc {})
  end

  describe ".up" do
    context "when the FK table is created in the same instruction set" do
      it "sets validate to true on the FK" do
        fk_instruction = fk(table: :payments)
        described_class.up([create_table(:payments), fk_instruction])
        expect(fk_instruction.extra_args).to include(validate: true)
      end

      it "is order-independent when FK comes before create_table" do
        fk_instruction = fk(table: :payments)
        described_class.up([fk_instruction, create_table(:payments)])
        expect(fk_instruction.extra_args).to include(validate: true)
      end
    end

    context "when a different table is created" do
      it "leaves validate as false" do
        fk_instruction = fk(table: :payments)
        described_class.up([create_table(:widgets), fk_instruction])
        expect(fk_instruction.extra_args).to include(validate: false)
      end
    end

    context "when no table is created" do
      it "leaves validate as false" do
        fk_instruction = fk(table: :payments)
        described_class.up([fk_instruction])
        expect(fk_instruction.extra_args).to include(validate: false)
      end
    end

    context "with multiple FKs on the new table" do
      it "sets validate to true on all of them" do
        fk1 = fk(table: :payments, target: :mandates)
        fk2 = fk(table: :payments, target: :customers)
        described_class.up([create_table(:payments), fk1, fk2])
        expect(fk1.extra_args).to include(validate: true)
        expect(fk2.extra_args).to include(validate: true)
      end
    end
  end

  describe ".down" do
    it "is a no-op" do
      fk_instruction = fk(table: :payments)
      described_class.down([create_table(:payments), fk_instruction])
      expect(fk_instruction.extra_args).to include(validate: false)
    end
  end
end
