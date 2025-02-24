# frozen_string_literal: true

module CustomFields
  module Fields
    # Allows entry of a user-defined custom field specification.
    class SpecField < Field
      def type
        :spec
      end

      def normalize(value)
        return nil if value.nil?

        value = value.strip
        return nil if value.blank?

        YAML.safe_load(value).to_yaml.gsub(/(\A---|\.\.\.\s*\z)/m, "").strip
      rescue Psych::SyntaxError
        value
      end

      def input_type
        :text
      end

      protected

      def set_implicit_validations
        super
        validation[:spec_yaml] = true
      end
    end
  end
end
