module CustomFields
  module Fields
    class BooleanField < Field
      def type
        :boolean
      end

      def value_input_param
        {input_html: {checked: yield}}
      end
    end
  end
end
