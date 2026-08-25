# frozen_string_literal: true

module Nandi
  class Migration::Yugabyte < Nandi::Migration
    INDEX_YB_TERMS = %i[bucket_on bucket_count].freeze

    def add_index(table, fields, **kwargs)
      return super unless INDEX_YB_TERMS.any? { |k| kwargs.key?(k) }

      current_instructions << Instructions::Yugabyte::AddIndexYb.new(
        **kwargs,
        table: table,
        fields: fields,
      )
    end
  end
end
