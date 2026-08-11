# frozen_string_literal: true

require "cell"
require "tilt"

module Nandi
  module Renderers
    class AbstractGenerate < ::Cell::ViewModel
      def self.call(*args)
        super.call
      end

      def partials_base
        raise NotImplementedError
      end

      def template_options_for(_options)
        {
          suffix: "rb.erb",
          template_class: Tilt,
        }
      end

      # TODO: Is this relative to the current file?
      self.view_paths = [
        File.expand_path("../../templates", __dir__),
      ]

      # TODO: Is this postgres specific?
      def should_disable_ddl_transaction?
        [*up_instructions, *down_instructions].
          any? { |i| i.procedure.to_s.include?("index") }
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
