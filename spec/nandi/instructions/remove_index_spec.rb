# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/remove_index"

RSpec.describe Nandi::Instructions::RemoveIndex do
  let(:instance) { described_class.new(table: table, field: field) }
  let(:table) { :widgets }
  let(:field) { :foo }

  describe "#table" do
    let(:table) { :thingumyjiggers }

    it "exposes the initial value" do
      expect(instance.table).to eq(:thingumyjiggers)
    end
  end

  describe "#extra_args" do
    subject(:args) { instance.extra_args }

    context "with a field" do
      it { is_expected.to eq(column: :foo, algorithm: :concurrently) }
    end

    context "with an array of fields" do
      let(:field) { %i[foo bar] }

      it { is_expected.to eq(column: %i[foo bar], algorithm: :concurrently) }
    end

    context "with a hash of arguments" do
      let(:field) { { name: :my_useless_index } }

      it "adds the algorithm: :concurrently setting" do
        expect(args).to eq(
          name: :my_useless_index,
          algorithm: :concurrently,
        )
      end
    end
  end
end
