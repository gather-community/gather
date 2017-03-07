module CustomFields
  module Fields
    class EnumField < Field
      def type
        :enum
      end

      def input_params
        {collection: options}
      end
    end
  end
end
