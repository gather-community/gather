module CustomFields
  module Fields
    class TextField < Field
      def type
        :text
      end

      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end
    end
  end
end
