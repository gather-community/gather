module CustomFields
  module Fields
    class EnumField < Field
      def type
        :enum
      end

      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end

      def input_type
        :select
      end

      def collection
        options
      end

      def value_input_param
        {selected: yield}
      end

      protected

      def set_implicit_validations
        super
        validation[:inclusion] ||= {in: options}
      end
    end
  end
end
