# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/remove_index"
require "nandi/migration"

RSpec.describe Nandi::Instructions::RemoveIndex do
  let(:instance) { described_class.new(table: table, field: field, concurrently: concurrently) }
  let(:table) { :widgets }
  let(:field) { :foo }
  let(:concurrently) { true }

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

    context "when concurrently is false" do
      let(:concurrently) { false }

      it "omits the algorithm key" do
        expect(args).to eq(column: :foo)
      end

      context "with a hash of arguments" do
        let(:field) { { name: :my_useless_index } }

        it "omits the algorithm key" do
          expect(args).to eq(name: :my_useless_index)
        end
      end
    end
  end

  describe "#lock" do
    context "when concurrently is true" do
      it "is SHARE" do
        expect(instance.lock).to eq(Nandi::Migration::LockWeights::SHARE)
      end
    end

    context "when concurrently is false" do
      let(:concurrently) { false }

      it "is ACCESS_EXCLUSIVE" do
        expect(instance.lock).to eq(Nandi::Migration::LockWeights::ACCESS_EXCLUSIVE)
      end
    end
  end

  describe "#concurrent?" do
    context "when concurrently is true" do
      it { expect(instance.concurrent?).to be(true) }
    end

    context "when concurrently is false" do
      let(:concurrently) { false }

      it { expect(instance.concurrent?).to be(false) }
    end
  end

  describe "default concurrently value" do
    subject(:instance) { described_class.new(table: table, field: field) }

    it "defaults to true" do
      expect(instance.concurrent?).to be(true)
    end
  end
end
