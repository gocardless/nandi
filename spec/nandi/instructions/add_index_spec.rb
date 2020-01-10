# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/add_index"

RSpec.describe Nandi::Instructions::AddIndex do
  let(:instance) do
    described_class.new(
      fields: fields,
      table: table,
      **extra_args,
    )
  end

  let(:fields) { :foo }
  let(:extra_args) { {} }
  let(:table) { :widgets }

  describe "#fields" do
    subject(:result) { instance.fields }

    context "with one field" do
      context "specified without an Array" do
        let(:fields) { :foo }

        it { is_expected.to eq(:foo) }
      end

      context "specified as an Array" do
        let(:fields) { [:foo] }

        it { is_expected.to eq(:foo) }
      end
    end

    context "with an array of fields" do
      let(:fields) { %i[foo bar] }

      it { is_expected.to eq(%i[foo bar]) }
    end
  end

  describe "#table" do
    let(:table) { :thingumyjiggers }

    it "exposes the initial value" do
      expect(instance.table).to eq(:thingumyjiggers)
    end
  end

  describe "#extra_args" do
    subject(:args) { instance.extra_args }

    context "with no extra args passed" do
      let(:extra_args) { {} }

      it "sets appropriate defaults" do
        expect(args).to eq(
          algorithm: :concurrently,
          using: :btree,
          name: :idx_widgets_on_foo,
        )
      end

      context "with fields containing operators" do
        let(:fields) { "((reports::json->>'source_id'))" }

        it "generates a readable index name" do
          expect(args[:name]).to eq(:idx_widgets_on_reports_json_source_id)
        end
      end
    end

    context "with custom name" do
      let(:extra_args) { { name: :my_amazing_index } }

      it "allows override" do
        expect(args).to eq(
          algorithm: :concurrently,
          using: :btree,
          name: :my_amazing_index,
        )
      end
    end

    context "with custom algorithm and using values" do
      let(:extra_args) { { algorithm: :paxos, using: :gin } }

      it "does not allow override" do
        expect(args).to eq(
          algorithm: :concurrently,
          using: :btree,
          name: :idx_widgets_on_foo,
        )
      end
    end
  end
end
