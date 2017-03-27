module CustomFields
  module Fields
    class TextualField < Field
      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end
    end
  end
end
