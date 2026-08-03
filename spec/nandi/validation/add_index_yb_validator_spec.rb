# frozen_string_literal: true

require "spec_helper"
require "nandi/validation/add_index_yb_validator"
require "nandi/migration"
require "nandi/instructions"

RSpec.describe Nandi::Validation::AddIndexYbValidator do
  subject(:validator) { described_class.call(instruction) }

  let(:instruction) do
    Nandi::Instructions::Yugabyte::AddIndexYb.new(
      table: :payments,
      fields: [:foo],
    )
  end

  before do
    Nandi.instance_variable_set(:@config, nil) # Reset config
  end

  describe "when the target database is not configured as yugabyte" do
    it { is_expected.to be_failure }

    it "explains why it failed" do
      expect(validator.failure).to eq(
        "add_index_yb: this instruction can only be used when the target database is " \
        "configured as YugabyteDB (pass `yugabyte_database: true` to `register_database`).",
      )
    end
  end

  describe "when the target database is configured as yugabyte" do
    before do
      Nandi.config.register_database(:primary, yugabyte_database: true)
    end

    it { is_expected.to be_success }
  end
end
