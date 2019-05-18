# frozen_string_literal: true

require "spec_helper"
require "nandi/validator"
require "nandi/instructions"

RSpec.describe Nandi::Validator do
  subject(:validator) { described_class.call(instructions) }

  context "creating an index" do
    context "with one new index" do
      let(:instructions) do
        [
          Nandi::Instructions::CreateIndex.new(
            table: :payments,
            fields: [:foo],
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "with more than one new index" do
      let(:instructions) do
        [
          Nandi::Instructions::CreateIndex.new(
            table: :payments,
            fields: [:foo],
          ),
          Nandi::Instructions::CreateIndex.new(
            table: :payments,
            fields: [:foo],
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end

  context "dropping an index" do
    context "dropping an index by index name" do
      let(:instructions) do
        [
          Nandi::Instructions::DropIndex.new(
            table: :payments,
            field: { name: :index_payments_on_foo },
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "dropping an index by column name" do
      let(:instructions) do
        [
          Nandi::Instructions::DropIndex.new(
            table: :payments,
            field: { column: %i[foo] },
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "dropping an index without valid props" do
      let(:instructions) do
        [
          Nandi::Instructions::DropIndex.new(
            table: :payments,
            field: { very: :irrelevant },
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end

  context "with more than one object modified" do
    let(:instructions) do
      [
        Nandi::Instructions::DropIndex.new(
          table: :payments,
          field: { name: :index_payments_on_foo },
        ),
        Nandi::Instructions::DropIndex.new(
          table: :mandates,
          field: { name: :index_payments_on_foo },
        ),
      ]
    end

    it { is_expected.to_not be_valid }
  end

  context "with one object modified as string and symbol" do
    let(:instructions) do
      [
        Nandi::Instructions::DropIndex.new(
          table: :payments,
          field: { name: :index_payments_on_foo },
        ),
        Nandi::Instructions::DropIndex.new(
          table: "payments",
          field: { name: :index_payments_on_foo },
        ),
      ]
    end

    it { is_expected.to be_valid }
  end

  context "adding a column" do
    context "a valid instruction" do
      let(:instructions) do
        [
          Nandi::Instructions::AddColumn.new(
            table: :payments,
            name: :stuff,
            type: :text,
            null: true,
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "with null: false" do
      let(:instructions) do
        [
          Nandi::Instructions::AddColumn.new(
            table: :payments,
            name: :stuff,
            type: :text,
            null: false,
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end

    context "with a default value" do
      let(:instructions) do
        [
          Nandi::Instructions::AddColumn.new(
            table: :payments,
            name: :stuff,
            type: :text,
            null: true,
            default: "swilly!",
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "with a unique constraint" do
      let(:instructions) do
        [
          Nandi::Instructions::AddColumn.new(
            table: :payments,
            name: :stuff,
            type: :text,
            null: true,
            unique: true,
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end

  context "altering a column" do
    context "making a column nullable" do
      let(:instructions) do
        [
          Nandi::Instructions::AlterColumn.new(
            table: :payments,
            name: :stuff,
            null: true,
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "changing the default value" do
      let(:instructions) do
        [
          Nandi::Instructions::AlterColumn.new(
            table: :payments,
            name: :stuff,
            default: "Zalgo comes",
          ),
        ]
      end

      it { is_expected.to be_valid }
    end

    context "making a column not nullable" do
      let(:instructions) do
        [
          Nandi::Instructions::AlterColumn.new(
            table: :payments,
            name: :stuff,
            null: false,
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end

    context "making a column unique" do
      let(:instructions) do
        [
          Nandi::Instructions::AlterColumn.new(
            table: :payments,
            name: :stuff,
            unique: true,
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end

    context "changing the type" do
      let(:instructions) do
        [
          Nandi::Instructions::AlterColumn.new(
            table: :payments,
            name: :stuff,
            type: :integer,
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end
end
