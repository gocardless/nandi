# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/timeout_policies"
require "nandi/timeout_policies/concurrent"

RSpec.describe Nandi::TimeoutPolicies::Concurrent do
  describe "::validate" do
    subject(:validate) { described_class.validate(migration) }

    let(:migration) do
      instance_double(Nandi::Migration,
                      statement_timeout: statement_timeout,
                      lock_timeout: lock_timeout,
                      database_name: database_name)
    end

    let(:database_name) { nil }

    before do
      allow(migration).to receive_messages(disable_statement_timeout?: false, disable_lock_timeout?: false)
      allow(Nandi.config).to receive_messages(concurrent_statement_timeout_min: 30_000,
                                              concurrent_lock_timeout_min: 10_000)
    end

    context "with valid timeouts" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 10_000 }

      it { is_expected.to be_success }
    end

    context "with too-low statement timeout" do
      let(:statement_timeout) { 29_999 }
      let(:lock_timeout) { 10_000 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "statement timeout for concurrent operations must be at least 30000",
          ])
      end
    end

    context "with disabled statement timeout" do
      let(:statement_timeout) { 29_999 }
      let(:lock_timeout) { 10_000 }

      before do
        allow(migration).to receive(:disable_statement_timeout?).and_return(true)
      end

      it { is_expected.to be_success }
    end

    context "with too-low lock timeout" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 9_999 }

      it { is_expected.to be_failure }

      it "yields an informative message" do
        expect(validate.failure).
          to eq([
            "lock timeout for concurrent operations must be at least 10000",
          ])
      end
    end

    context "with disabled lock timeout" do
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 9_999 }

      before do
        allow(migration).to receive(:disable_lock_timeout?).and_return(true)
      end

      it { is_expected.to be_success }
    end

    context "with a migration for a specific database" do
      let(:database_name) { :analytics }
      let(:statement_timeout) { 30_000 }
      let(:lock_timeout) { 10_000 }

      it { is_expected.to be_success }

      it "resolves timeouts using the migration's database_name" do
        expect(Nandi.config).to receive(:concurrent_statement_timeout_min).
          with(:analytics).at_least(:once).and_return(30_000)
        expect(Nandi.config).to receive(:concurrent_lock_timeout_min).
          with(:analytics).at_least(:once).and_return(10_000)

        validate
      end
    end
  end
end
