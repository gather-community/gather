module CustomFields
  module Fields
    class EnumField < Field
      def type
        :enum
      end

      def input_type
        :select
      end

      def collection
        options
      end
    end
  end
end
