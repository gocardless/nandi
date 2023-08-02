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
      let(:instruction) { instance_double(Nandi::Instructions::RemoveIndex) }

      before do
        allow(instruction).to receive(:procedure).and_return(:remove_index)
      end

      it "calls RemoveIndexValidator" do
        expect(Nandi::Validation::RemoveIndexValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction is to add a column" do
      let(:instruction) { instance_double(Nandi::Instructions::AddColumn) }

      before do
        allow(instruction).to receive(:procedure).and_return(:add_column)
      end

      it "calls AddColumnValidator" do
        expect(Nandi::Validation::AddColumnValidator).to receive(:call).with(instruction)

        call
      end
    end

    context "when the given instruction is to add a reference" do
      let(:instruction) { instance_double(Nandi::Instructions::AddReference) }

      before do
        allow(instruction).to receive(:procedure).and_return(:add_reference)
      end

      it "calls AddReferenceValidator" do
        expect(Nandi::Validation::AddReferenceValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction is to add an index" do
      let(:instruction) { instance_double(Nandi::Instructions::AddIndex) }

      before do
        allow(instruction).to receive(:procedure).and_return(:add_index)
      end

      it "calls AddIndexValidator" do
        expect(Nandi::Validation::AddIndexValidator).to receive(:call).
          with(instruction)

        call
      end
    end

    context "when the given instruction isn't explicitly validated" do
      let(:instruction) { instance_double(Nandi::Instructions::AddForeignKey) }

      before do
        allow(instruction).to receive(:procedure).and_return(:add_foreign_key)
      end

      it "returns successful" do
        expect(call).to eq(Dry::Monads::Result::Success.new(nil))
      end
    end
  end
end
