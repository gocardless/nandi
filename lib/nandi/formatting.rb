# frozen_string_literal: true

module Nandi
  module Formatting
    class UnsupportedValueError < StandardError; end

    module ClassMethods
      # Define an accessor method that will retrieve a value
      # from a cell's model and format it with the format_value
      # method below.
      # @param name [String] the attribute on model to retrieve
      # @example formatting the foo property
      #   class MyCell < Cells::ViewModel
      #     include Nandi::Formatting
      #
      #     formatted_property :foo
      #   end
      def formatted_property(name)
        define_method(name) do
          format_value(model.send(name))
        end
      end
    end

    # Create a string representation of the value that is a valid
    # and correct Ruby literal for that value. Please note that the
    # exact representation is not guaranteed to be the same between
    # different platforms and Ruby versions. The guarantee is merely
    # that calling this method with any supported type will produce
    # a string that produces an equal value when it is passed to
    # Kernel::eval
    # @param value [Hash, Array, String, Symbol, Integer, Float, NilClass]
    #   value to format
    def format_value(value, opts = {})
      case value
      when Hash
        format_hash(value, opts)
      when Array
        "[#{value.map { |v| format_value(v, opts) }.join(', ')}]"
      when String, Symbol, Integer, Float, NilClass, TrueClass, FalseClass
        value.inspect
      else
        raise UnsupportedValueError,
              "Cannot format value of type #{value.class.name}"
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    private

    def format_hash(value, opts)
      if opts[:as_argument]
        hash_pairs(value).join(", ")
      else
        "{\n  #{hash_pairs(value).join(",\n  ")}\n}"
      end
    end

    def hash_pairs(value)
      value.map do |k, v|
        key = if k.is_a?(Symbol)
                symbol_key(k)
              else
                "#{format_value(k)} =>"
              end
        "#{key} #{format_value(v)}"
      end
    end

    def symbol_key(key)
      canonical = key.inspect

      "#{canonical[1..]}:"
    end
  end
end
