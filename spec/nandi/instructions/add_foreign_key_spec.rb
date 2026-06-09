# frozen_string_literal: true

require "spec_helper"
require "nandi/instructions/add_foreign_key"

RSpec.describe Nandi::Instructions::AddForeignKey do
  subject(:instruction) { described_class.new(table: :payments, target: :mandates) }

  describe "#extra_args" do
    it "defaults validate to false" do
      expect(instruction.extra_args).to include(validate: false)
    end
  end

  describe "#validate!" do
    before { instruction.validate! }

    it "sets validate to true in extra_args" do
      expect(instruction.extra_args).to include(validate: true)
    end
  end
end
