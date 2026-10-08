# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/extend_varchar_column_limit"

RSpec.describe Nandi::Instructions::ExtendVarcharColumnLimit do
  subject(:instruction) do
    described_class.new(table: :widgets, column: :name, from:, to:)
  end

  let(:from) { 2 }
  let(:to) { 16 }

  it "exposes the table, column and new limit" do
    expect(instruction).to have_attributes(table: :widgets, column: :name, from: 2, to: 16)
  end

  context "when removing the limit entirely" do
    let(:to) { nil }

    it "is allowed" do
      expect(instruction.to).to be_nil
    end
  end

  context "when narrowing the limit" do
    let(:from) { 16 }
    let(:to) { 2 }

    it "raises" do
      expect { instruction }.to raise_error(ArgumentError, /only supports widening/)
    end
  end

  context "when the limit is unchanged" do
    let(:from) { 2 }
    let(:to) { 2 }

    it "raises" do
      expect { instruction }.to raise_error(ArgumentError, /only supports widening/)
    end
  end

  context "when from is not an integer" do
    let(:from) { nil }

    it "raises" do
      expect { instruction }.to raise_error(ArgumentError, /requires an integer/)
    end
  end
end
