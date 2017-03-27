module CustomFields
  module Fields
    class StringField < Field
      def type
        :string
      end

      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end
    end
  end
end
