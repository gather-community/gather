module CustomFields
  module Fields
    # Models the definition of single group field, which is a field composed of sub-fields.
    class GroupField < Field
      attr_accessor :fields

      def initialize(key:, fields:)
        super(key: key)
        self.fields = fields.map do |field_data|
          field_data.symbolize_keys!
          klass = "CustomFields::Fields::#{field_data.delete(:type).to_s.classify}Field"
          klass.constantize.new(field_data)
        end
      end

      def type
        :group
      end

      def group?
        true
      end

      def root?
        key == :__root__
      end

      def keys
        @keys ||= fields.map(&:key)
      end

      # Returns a list of permitted keys in the form expected by strong params.
      def permitted
        fields.map { |f| f.group? ? {f.key => f.permitted} : f.key }
      end
    end
  end
end
