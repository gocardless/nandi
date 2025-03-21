# frozen_string_literal: true

require "spec_helper"
require "nandi/validator"
require "nandi/migration"
require "nandi/instructions"

RSpec.describe Nandi::Validator do
  subject(:validator) { described_class.call(migration) }

  let(:strictest_lock) { Nandi::Migration::LockWeights::SHARE }
  let(:statement_timeout) { 1_000 }
  let(:lock_timeout) { 750 }

  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout,
                    strictest_lock: strictest_lock)
  end

  before do
    allow(migration).to receive_messages(disable_statement_timeout?: false, disable_lock_timeout?: false)
  end

  context "creating an index" do
    before do
      allow(migration).to receive_messages(disable_statement_timeout?: true, disable_lock_timeout?: true)
    end

    context "with one new index" do
      let(:instructions) do
        [
          Nandi::Instructions::AddIndex.new(
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
          Nandi::Instructions::AddIndex.new(
            table: :payments,
            fields: [:foo],
          ),
          Nandi::Instructions::AddIndex.new(
            table: :payments,
            fields: [:foo],
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end

  context "dropping an index" do
    before do
      allow(migration).to receive_messages(disable_statement_timeout?: true, disable_lock_timeout?: true)
    end

    context "dropping an index by index name" do
      let(:instructions) do
        [
          Nandi::Instructions::RemoveIndex.new(
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
          Nandi::Instructions::RemoveIndex.new(
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
          Nandi::Instructions::RemoveIndex.new(
            table: :payments,
            field: { very: :irrelevant },
          ),
        ]
      end

      it { is_expected.to_not be_valid }
    end
  end

  context "with an irreversible migration" do
    let(:instructions) { [Nandi::Instructions::IrreversibleMigration.new] }

    it { is_expected.to be_valid }
  end

  context "with more than one object modified" do
    let(:instructions) do
      [
        Nandi::Instructions::RemoveIndex.new(
          table: :payments,
          field: { name: :index_payments_on_foo },
        ),
        Nandi::Instructions::RemoveIndex.new(
          table: :mandates,
          field: { name: :index_payments_on_foo },
        ),
      ]
    end

    it { is_expected.to_not be_valid }
  end

  context "with one object modified as string and symbol" do
    before do
      allow(migration).to receive_messages(disable_statement_timeout?: true, disable_lock_timeout?: true)
    end

    let(:instructions) do
      [
        Nandi::Instructions::RemoveIndex.new(
          table: :payments,
          field: { name: :index_payments_on_foo },
        ),
        Nandi::Instructions::RemoveIndex.new(
          table: "payments",
          field: { name: :index_payments_on_foo },
        ),
      ]
    end

    it { is_expected.to be_valid }
  end

  context "adding a column" do
    context "with null: true" do
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

    context "with no null value" do
      let(:instructions) do
        [
          Nandi::Instructions::AddColumn.new(
            table: :payments,
            name: :stuff,
            type: :text,
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

      context "and a default" do
        let(:instructions) do
          [
            Nandi::Instructions::AddColumn.new(
              table: :payments,
              name: :stuff,
              type: :text,
              null: false,
              default: "swilly!",
            ),
          ]
        end

        it { is_expected.to be_valid }
      end
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

  context "with too great a statement timeout" do
    let(:strictest_lock) { Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE }
    let(:statement_timeout) { 2_000 }

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

    it { is_expected.to_not be_valid }
  end

  context "with too great a lock timeout" do
    let(:strictest_lock) { Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE }
    let(:lock_timeout) { 20_000 }

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

    it { is_expected.to_not be_valid }
  end

  context "adding a reference" do
    let(:instructions) do
      [
        Nandi::Instructions::AddReference.new(
          table: :payments,
          ref_name: :mandate,
          **options,
        ),
      ]
    end

    context "with no options" do
      let(:options) { {} }

      it { is_expected.to be_valid }
    end

    context "with valid options" do
      let(:options) { { type: :text } }

      it { is_expected.to be_valid }
    end

    context "with foreign_key: true" do
      let(:options) { { foreign_key: true } }

      it { is_expected.to_not be_valid }
    end

    context "with index: true" do
      let(:options) { { index: true } }

      it { is_expected.to_not be_valid }
    end
  end
end
