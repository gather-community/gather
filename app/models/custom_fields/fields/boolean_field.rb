# frozen_string_literal: true

module CustomFields
  module Fields
    class BooleanField < Field
      def type
        :boolean
      end

      def normalize(value)
        if [true, false].include?(value)
          value
        elsif %w[1 true].include?(value.to_s)
          true
        elsif %w[0 false].include?(value.to_s)
          false
        end
      end

      def value_input_param
        {input_html: {checked: yield}}
      end
    end
  end
end
