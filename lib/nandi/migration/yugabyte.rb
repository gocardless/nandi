# frozen_string_literal: true

module Nandi
  class Migration::Yugabyte < Nandi::Migration
    def add_index(table, fields, **kwargs)
      current_instructions << Instructions::Yugabyte::AddIndexYb.new(
        **kwargs,
        table: table,
        fields: fields,
      )
    end
  end
end

