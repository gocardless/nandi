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
                          procedure: :create_index),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "with more than one new index" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::CreateIndex,
                          procedure: :create_index),
          instance_double(Nandi::Instructions::CreateIndex,
                          procedure: :create_index),
        ]
      end

      it { is_expected.to eq(false) }
    end
  end

  describe "#drop_index" do
    context "dropping an index by index name" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::CreateIndex,
                          procedure: :drop_index,
                          arguments: [:payments, { name: :index_payments_on_foo }]),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "dropping an index by column name" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::CreateIndex,
                          procedure: :drop_index,
                          arguments: [:payments, { column: %i[foo] }]),
        ]
      end

      it { is_expected.to eq(true) }
    end

    context "dropping an index without valid props" do
      let(:instructions) do
        [
          instance_double(Nandi::Instructions::CreateIndex,
                          procedure: :drop_index,
                          arguments: [:payments, { very: :irrelevant }]),
        ]
      end

      it { is_expected.to eq(false) }
    end
  end
end
