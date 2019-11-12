# frozen_string_literal: true

module CustomFields
  module Fields
    class TimeZoneField < Field
      def type
        :time_zone
      end

      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end

      def input_type
        :time_zone
      end

      def value_input_param
        {selected: yield}
      end
    end
  end
end
