module CustomFields
  module Fields
    class EmailField < TextualField
      def type
        :email
      end

      def normalize(value)
        stripped = value.try(:strip)
        stripped == "" ? nil : stripped
      end

      protected

      def set_implicit_validations
        super
        validation[:format] ||= {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, allow_nil: true}
      end
    end
  end
end
