# frozen_string_literal: true

require "spec_helper"
require "nandi/validation/add_index_validator"
require "nandi/migration"
require "nandi/instructions"

RSpec.describe Nandi::Validation::AddIndexValidator do
  subject(:validator) { described_class.call(instruction) }

  describe "with a hash index in the contained migration" do
    let(:instruction) do
      Nandi::Instructions::AddIndex.new(
        table: :payments,
        fields: [:foo],
        using: :hash,
      )
    end

    it { is_expected.to be_failure }
  end

  describe "without a hash index in the contained migration" do
    let(:instruction) do
      Nandi::Instructions::AddIndex.new(
        table: :payments,
        fields: [:foo],
      )
    end

    it { is_expected.to be_success }
  end
end
