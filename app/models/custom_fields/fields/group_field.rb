module CustomFields
  module Fields
    # Models the definition of single group field, which is a field composed of sub-fields.
    class GroupField < Field
      attr_accessor :items

      def initialize(key:, items:)
        super(key: key)
        self.items = items.map do |item|
          item.symbolize_keys!
          klass = "CustomFields::Fields::#{item.delete(:type).capitalize}Field"
          klass.constantize.new(item)
        end
      end

      def type
        :group
      end

      def keys
        @keys ||= items.map(&:key)
      end

      def input_params
        raise NotImplementedError
      end
    end
  end
end
