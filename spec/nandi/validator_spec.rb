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
          instance_double(Nandi::Instructions::CreateIndex,
                          table: :payments,
                          procedure: :create_index),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "with more than one new index" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::CreateIndex,
                          table: :payments,
                          procedure: :create_index),
          instance_double(Nandi::Instructions::CreateIndex,
                          table: :payments,
                          procedure: :create_index),
        ]
      end

      it { is_expected.to eq(false) }
    end
  end

  context "dropping an index" do
    context "dropping an index by index name" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::DropIndex,
                          table: :payments,
                          procedure: :drop_index,
                          arguments: [:payments, { name: :index_payments_on_foo }]),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "dropping an index by column name" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::DropIndex,
                          table: :payments,
                          procedure: :drop_index,
                          arguments: [:payments, { column: %i[foo] }]),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "dropping an index without valid props" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::DropIndex,
                          table: :payments,
                          procedure: :drop_index,
                          arguments: [:payments, { very: :irrelevant }]),
        ]
      end

      it { is_expected.to eq(false) }
    end
  end

  context "with more than one object modified" do
    let(:instructions) do
      [
        instance_double(Nandi::Instructions::DropIndex,
                        table: :payments,
                        procedure: :drop_index,
                        arguments: [:payments, { name: :index_payments_on_foo }]),
        instance_double(Nandi::Instructions::DropIndex,
                        table: :mandates,
                        procedure: :drop_index,
                        arguments: [:mandates, { name: :index_payments_on_foo }]),
      ]
    end

    it { is_expected.to eq(false) }
  end

  context "with one object modified as string and symbol" do
    let(:instructions) do
      [
        instance_double(Nandi::Instructions::DropIndex,
                        table: :payments,
                        procedure: :drop_index,
                        arguments: [:payments, { name: :index_payments_on_foo }]),
        instance_double(Nandi::Instructions::DropIndex,
                        table: "payments",
                        procedure: :drop_index,
                        arguments: ["payments", { name: :index_payments_on_foo }]),
      ]
    end

    it { is_expected.to eq(true) }
  end
end
