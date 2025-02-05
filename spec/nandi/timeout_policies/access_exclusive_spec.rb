# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/timeout_policies"
require "nandi/timeout_policies/access_exclusive"

RSpec.describe Nandi::TimeoutPolicies::AccessExclusive do
  describe "::validate" do
    subject(:validate) { described_class.validate(migration) }

    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout)
    end

    before do
      allow(migration).to receive_messages(disable_statement_timeout?: false, disable_lock_timeout?: false)
      allow(Nandi.config).to receive_messages(access_exclusive_statement_timeout_limit: 1500,
                                              access_exclusive_lock_timeout_limit: 750)
    end

    context "with valid timeouts" do
      let(:statement_timeout) { 1499 }
      let(:lock_timeout) { 749 }

      it { is_expected.to be_success }
    end

    context "with too-long statement timeout" do
      let(:statement_timeout) { 1501 }
      let(:lock_timeout) { 749 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "statement timeout must be at most 1500ms " \
            "as it takes an ACCESS EXCLUSIVE lock",
          ])
      end
    end

    context "with disabled statement timeout" do
      let(:statement_timeout) { 1500 }
      let(:lock_timeout) { 749 }

      before do
        allow(migration).to receive(:disable_statement_timeout?).
          and_return(true)
      end

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "statement timeout must be at most 1500ms " \
            "as it takes an ACCESS EXCLUSIVE lock",
          ])
      end
    end

    context "with too-long lock timeout" do
      let(:statement_timeout) { 1499 }
      let(:lock_timeout) { 751 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "lock timeout must be at most 750ms as it takes an ACCESS EXCLUSIVE lock",
          ])
      end
    end

    context "with disabled lock timeout" do
      let(:statement_timeout) { 1499 }
      let(:lock_timeout) { 749 }

      before do
        allow(migration).to receive(:disable_lock_timeout?).
          and_return(true)
      end

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "lock timeout must be at most 750ms as it takes an ACCESS EXCLUSIVE lock",
          ])
      end
    end
  end
end
