# frozen_string_literal: true

module CustomFields
  module Validations
    # Validates YAML that defines a user-defined custom field spec.
    class SpecYamlValidator < ActiveModel::EachValidator
      def initialize(options)
        options.reverse_merge!(message: :invalid)
        super
      end

      def validate_each(record, attribute, value)
        return nil if value.blank?

        value = value.strip if value.is_a?(String)
        begin
          value = YAML.safe_load(value)
        rescue Psych::SyntaxError
          record.errors.add(attribute, "Invalid YAML")
        end
        begin
          CustomFields::Spec.new(value)
        rescue NameError, ArgumentError, NoMethodError
          record.errors.add(attribute, "This specification is invalid. " \
                                       "Please contact Gather support for assistance.")
        end
      end
    end
  end
end
