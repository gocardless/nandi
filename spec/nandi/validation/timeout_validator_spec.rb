# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/validation/timeout_validator"
require "nandi/migration"
require "nandi/instructions"

RSpec.describe Nandi::Validation::TimeoutValidator do
  subject(:validator) { described_class.call(migration) }

  let(:statement_timeout) { 1_000 }
  let(:lock_timeout) { 750 }

  let(:migration) do
    instance_double(Nandi::Migration,
                    up_instructions: instructions,
                    down_instructions: [],
                    statement_timeout: statement_timeout,
                    lock_timeout: lock_timeout)
  end

  before do
    allow(migration).to receive(:disable_statement_timeout?).
      and_return(false)
    allow(migration).to receive(:disable_lock_timeout?).
      and_return(false)
    allow(Nandi.config).to receive(:access_exclusive_lock_timeout_limit).
      and_return(750)
    allow(Nandi.config).to receive(:access_exclusive_statement_timeout_limit).
      and_return(1500)
    allow(Nandi.config).to receive(:access_exclusive_lock_timeout_limit).
      and_return(750)
  end

  context "with an ACCESS EXCLUSIVE instruction" do
    let(:instructions) do
      [
        Nandi::Instructions::AddColumn.new(
          table: :payments,
          name: :stuff,
          type: :text,
          null: true,
          default: "swilly!",
        ),
      ]
    end

    it { is_expected.to be_success }

    context "with timeouts disabled" do
      before do
        allow(migration).to receive(:disable_statement_timeout?).
          and_return(true)
        allow(migration).to receive(:disable_lock_timeout?).
          and_return(true)
      end

      it { is_expected.to be_failure }
    end

    context "with too great a statement timeout" do
      let(:statement_timeout) { 1501 }

      it { is_expected.to be_failure }
    end

    context "with too great a lock timeout" do
      let(:lock_timeout) { 751 }

      it { is_expected.to be_failure }
    end
  end

  context "creating an index" do
    let(:instructions) do
      [
        Nandi::Instructions::AddIndex.new(
          table: :payments,
          fields: [:foo],
        ),
      ]
    end

    context "with huge timeouts set" do
      let(:lock_timeout) { Float::INFINITY }
      let(:statement_timeout) { Float::INFINITY }

      it { is_expected.to be_success }
    end

    context "with too-low statement timeout" do
      let(:lock_timeout) { Float::INFINITY }
      let(:statement_timeout) { 3_599_999 }

      it { is_expected.to be_failure }
    end
  end

  context "removing an index" do
    let(:instructions) do
      [
        Nandi::Instructions::RemoveIndex.new(
          table: :payments,
          field: :foo,
        ),
      ]
    end

    context "with timeouts disabled" do
      before do
        allow(migration).to receive(:disable_statement_timeout?).
          and_return(true)
        allow(migration).to receive(:disable_lock_timeout?).
          and_return(true)
      end

      it { is_expected.to be_success }
    end

    context "with huge timeouts set" do
      let(:lock_timeout) { Float::INFINITY }
      let(:statement_timeout) { Float::INFINITY }

      it { is_expected.to be_success }
    end

    context "with too-low statement timeout" do
      let(:lock_timeout) { Float::INFINITY }
      let(:statement_timeout) { 3_599_999 }

      it { is_expected.to be_failure }
    end

    context "with too-low lock timeout" do
      let(:statement_timeout) { Float::INFINITY }
      let(:lock_timeout) { 3_599_999 }

      it { is_expected.to be_failure }
    end
  end
end
