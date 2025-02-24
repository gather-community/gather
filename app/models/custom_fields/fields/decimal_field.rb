# frozen_string_literal: true

module CustomFields
  module Fields
    class DecimalField < Field
      def type
        :decimal
      end

      def normalize(value)
        if value.is_a?(Float)
          value
        elsif value.nil? || (value.is_a?(String) && value.strip == "")
          nil
        else
          value.to_f
        end
      end
    end
  end
end
