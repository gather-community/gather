module CustomFields
  module Fields
    class IntegerField < Field
      def type
        :integer
      end

      def normalize(value)
        if value.is_a?(Fixnum)
          value
        elsif value.nil? || value.is_a?(String) && value.strip == ""
          nil
        else
          value.to_i
        end
      end
    end
  end
end
