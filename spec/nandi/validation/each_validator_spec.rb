# frozen_string_literal: true

require "spec_helper"
require "nandi/validation/add_index_validator"
require "nandi/validation/remove_index_validator"
require "nandi/migration"
require "nandi/instructions"

RSpec.describe Nandi::Validation::EachValidator do
  subject(:call) { described_class.call(instruction) }

  describe "#call" do
    context "when the given instruction is to remove an index" do
      let(:instruction) { Nandi::Instructions::RemoveIndex.new(table: :payments, field: :foo) }

      it "calls RemoveIndexValidator" do
        expect(Nandi::Validation::RemoveIndexValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction is to add a column" do
      let(:instruction) { Nandi::Instructions::AddColumn.new(table: :payments, name: :foo, type: :text) }

      it "calls AddColumnValidator" do
        expect(Nandi::Validation::AddColumnValidator).to receive(:call).with(instruction)

        call
      end
    end

    context "when the given instruction is to add a reference" do
      let(:instruction) { Nandi::Instructions::AddReference.new(table: :payments, ref_name: :user) }

      it "calls AddReferenceValidator" do
        expect(Nandi::Validation::AddReferenceValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction is to add an index" do
      let(:instruction) { Nandi::Instructions::AddIndex.new(table: :payments, fields: [:foo]) }

      it "calls AddIndexValidator" do
        expect(Nandi::Validation::AddIndexValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction isn't explicitly validated" do
      let(:instruction) { Nandi::Instructions::AddForeignKey.new(table: :payments, target: :users) }

      it "returns successful" do
        expect(call).to eq(Dry::Monads::Result::Success.new(nil))
      end
    end
  end
end
