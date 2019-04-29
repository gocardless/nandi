# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/validator"

RSpec.describe Nandi::Migration do
  let(:validator) { Nandi::Validator }

  describe "name" do
    subject(:migration) { MyAmazingClass.new(validator).name }

    before do
      stub_const("MyAmazingClass", Class.new(described_class))
    end

    it { is_expected.to eq("MyAmazingClass") }
  end

  describe "#up and #down" do
    subject(:migration) { subject_class.new(validator) }

    context "with up but not down implemented" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end
        end
      end

      it { is_expected.to be_valid }
    end

    context "with down but not up implemented" do
      let(:subject_class) do
        Class.new(described_class) do
          def down; end
        end
      end

      it { is_expected.to_not be_valid }
    end
  end

  describe "#create_index" do
    context "with one new index" do
      subject(:instructions) { subject_class.new(validator).up_instructions }

      context "with one indexed field" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              create_index :payments, :foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:create_index)
        end
      end

      context "with more than one indexed field" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              create_index :payments, %i[foo bar]
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:create_index)
        end
      end
    end

    context "with extra args" do
      subject(:instructions) { subject_class.new(validator).up_instructions }

      let(:subject_class) do
        Class.new(described_class) do
          def up
            create_index :payments, :foo, extra: :arg
          end
        end
      end

      it "returns an instruction" do
        expect(instructions.first.procedure).to eq(:create_index)
      end
    end
  end

  describe "#drop_index" do
    subject(:instructions) { subject_class.new(validator).down_instructions }

    context "dropping an index by column name" do
      let(:subject_class) do
        Class.new(described_class) do
          def up; end

          def down
            drop_index :payments, :foo
          end
        end
      end

      it "returns an instruction" do
        expect(instructions.first.procedure).to eq(:drop_index)
      end
    end

    context "dropping an index by options hash" do
      context "with column property" do
        let(:subject_class) do
          Class.new(described_class) do
            def up; end

            def down
              drop_index :payments, column: :foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:drop_index)
        end
      end

      context "with name property" do
        let(:subject_class) do
          Class.new(described_class) do
            def up; end

            def down
              drop_index :payments, name: :index_payments_on_foo
            end
          end
        end

        it "returns an instruction" do
          expect(instructions.first.procedure).to eq(:drop_index)
        end
      end
    end
  end
end
