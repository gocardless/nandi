# frozen_string_literal: true

require "cell"
require "tilt"
require "nandi/renderers/active_record/instructions"

module Nandi
  module Renderers
    module ActiveRecord
      class Generate < ::Cell::ViewModel
        def self.call(*args)
          super.call
        end

        def partials_base
          "nandi/renderers/active_record/instructions"
        end

        def template_options_for(_options)
          {
            suffix: "rb.erb",
            template_class: Tilt,
          }
        end

        self.view_paths = [
          File.expand_path("../../../templates", __dir__),
        ]

        def should_disable_ddl_transaction?
          [*up_instructions, *down_instructions].
            select { |i| i.procedure =~ /index/ }.any?
        end

        def render_partial(instruction)
          if instruction.respond_to?(:template)
            cell(instruction.template, instruction)
          else
            cell("#{partials_base}/#{instruction.procedure}", instruction)
          end
        end

        property :up_instructions
        property :down_instructions
        property :name
        property :mixins
        property :disable_lock_timeout?
        property :disable_statement_timeout?
        property :lock_timeout
        property :statement_timeout
      end
    end
  end
end
