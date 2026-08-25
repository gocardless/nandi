# frozen_string_literal: true

require "spec_helper"
require "nandi/migration"
require "nandi/yugabyte/nandi/migration/yugabyte"
require "nandi/validator"

RSpec.describe Nandi::Migration::Yugabyte do
  let(:validator) { Nandi::Validator }

  describe "#add_index" do
    subject(:instructions) { subject_class.new(validator).up_instructions }

    context "with yugabyte-specific options" do
      context "with bucket_on" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, %i[foo bar], bucket_on: :id
            end
          end
        end

        it "returns an add_index_yb instruction" do
          expect(instructions.first.procedure).to eq(:add_index_yb)
        end

        it "is an instance of AddIndexYb" do
          expect(instructions.first).to be_a(Nandi::Instructions::Yugabyte::AddIndexYb)
        end
      end

      context "with bucket_count" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, %i[foo bar], bucket_on: :id, bucket_count: 16
            end
          end
        end

        it "returns an add_index_yb instruction" do
          expect(instructions.first.procedure).to eq(:add_index_yb)
        end

        it "is an instance of AddIndexYb" do
          expect(instructions.first).to be_a(Nandi::Instructions::Yugabyte::AddIndexYb)
        end
      end
    end

    context "without yugabyte-specific options" do
      context "with no extra args" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, %i[foo bar]
            end
          end
        end

        it "falls back to the default add_index instruction" do
          expect(instructions.first.procedure).to eq(:add_index)
        end

        it "is an instance of the base AddIndex instruction, not AddIndexYb" do
          expect(instructions.first).to be_a(Nandi::Instructions::AddIndex)
          expect(instructions.first).to_not be_a(Nandi::Instructions::Yugabyte::AddIndexYb)
        end
      end

      context "with other, non-yugabyte-specific extra args" do
        let(:subject_class) do
          Class.new(described_class) do
            def up
              add_index :payments, %i[foo bar], using: :hash
            end
          end
        end

        it "falls back to the default add_index instruction" do
          expect(instructions.first.procedure).to eq(:add_index)
        end

        it "forwards the extra args" do
          expect(instructions.first.extra_args).to include(using: :hash)
        end
      end
    end
  end
end
