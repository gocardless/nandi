# frozen_string_literal: true

require "spec_helper"
require "nandi/file_matcher"

RSpec.describe Nandi::FileMatcher do
  describe "::call" do
    subject(:match) { described_class.call(files: files, spec: spec) }

    let(:files) do
      [
        "20180402010101_do_thing_1.rb",
        "20190101010101_do_thing_2.rb",
        "20190102010101_do_thing_3.rb",
        "20190402010101_do_thing_4.rb",
      ]
    end

    context "all files" do
      let(:spec) { "all" }

      it { is_expected.to eq(Set.new(files)) }
    end

    context "git-diff" do
      let(:spec) { "git-diff" }

      before do
        allow_any_instance_of(described_class).to receive(:files_from_git_status).
          and_return(["20180402010101_do_thing_1.rb"])
      end

      it { is_expected.to eq(Set["20180402010101_do_thing_1.rb"]) }
    end

    context "timestamp" do
      context "without operator" do
        context "with full timestamp" do
          let(:spec) { "20190101010101" }

          it { is_expected.to eq(Set["20190101010101_do_thing_2.rb"]) }
        end

        context "with partial timestamp" do
          let(:spec) { "2019" }

          it "returns all matches" do
            expect(match).to eq(Set[
              "20190101010101_do_thing_2.rb",
              "20190102010101_do_thing_3.rb",
              "20190402010101_do_thing_4.rb",
            ])
          end
        end
      end

      context "with > operator" do
        let(:spec) { ">20190101010101" }

        
        it "returns all matches" do
          expect(match).to eq(Set[
            "20190102010101_do_thing_3.rb",
            "20190402010101_do_thing_4.rb",
          ])
        end
      end

      context "with >= operator" do
        let(:spec) { ">=20190101010101" }
        
        it "returns all matches" do
          expect(match).to eq(Set[
            "20190101010101_do_thing_2.rb",
            "20190102010101_do_thing_3.rb",
            "20190402010101_do_thing_4.rb",
          ])
        end
      end
    end
  end
end
