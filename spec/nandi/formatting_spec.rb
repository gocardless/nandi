# frozen_string_literal: true

require "spec_helper"
require "nandi/formatting"

RSpec.describe Nandi::Formatting do
  describe "#format_value" do
    subject(:result) { subject_class.new.format_value(value) }

    let(:subject_class) do
      Class.new(Object) do
        include Nandi::Formatting
      end
    end

    shared_examples "outputs valid ruby" do |input|
      let(:value) { input }

      # rubocop:disable Security/Eval
      it "evaluates to the same value" do
        expect(eval(result)).to eq(input)
      rescue SyntaxError
        raise StandardError, "not valid ruby: #{result}"
      end
      # rubocop:enable Security/Eval
    end

    context "with nil" do
      it_behaves_like "outputs valid ruby", nil
    end

    context "with a string" do
      it_behaves_like "outputs valid ruby", "string"
    end

    context "with a symbol" do
      it_behaves_like "outputs valid ruby", :foo
      it_behaves_like "outputs valid ruby", :"what-the-hell"
      it_behaves_like "outputs valid ruby", :"6"
    end

    context "with a number" do
      it_behaves_like "outputs valid ruby", 5
      it_behaves_like "outputs valid ruby", -5
      it_behaves_like "outputs valid ruby", 5.5
    end

    context "with an array" do
      it_behaves_like "outputs valid ruby", [1, 2, "foo", [:bar, "baz"]]
    end

    context "with a hash" do
      context "with symbol keys" do
        it_behaves_like "outputs valid ruby", foo: 5
        it_behaves_like "outputs valid ruby", foo: { bar: 5 }
        it_behaves_like "outputs valid ruby", łódź: 5
        it_behaves_like "outputs valid ruby", "lots of words": 5
      end

      context "with non-symbol keys" do
        it_behaves_like "outputs valid ruby", "łódź" => 5
        it_behaves_like "outputs valid ruby", "foo" => 5
        it_behaves_like "outputs valid ruby", "foo" => { "bar" => 5 }
      end

      context "inside an array" do
        let(:value) do
          [
            {
              foo: 5,
            },
          ]
        end

        it "formats the hash correctly" do
          expect(result).to eq("[{\n  foo: 5,\n}]")
        end
      end
    end

    context "with some arbitrary object" do
      let(:some_random_object) { Class.new(Object) }
      let(:value) { some_random_object.new }

      before do
        stub_const("SomeRandomObject", some_random_object)
      end

      it "throws" do
        expect { result }.to raise_error(Nandi::Formatting::UnsupportedValueError,
                                         "Cannot format value of type SomeRandomObject")
      end
    end
  end

  describe "::formatted_property" do
    subject(:result) { subject_class.new(model).my_hash }

    let(:subject_class) do
      Struct.new(:model) do
        include Nandi::Formatting

        formatted_property :my_hash
      end
    end

    let(:model) do
      Struct.new(:my_hash).new(foo: { bar: 5 })
    end

    it { is_expected.to eq("{\n  foo: {\n  bar: 5,\n},\n}") }
  end
end
