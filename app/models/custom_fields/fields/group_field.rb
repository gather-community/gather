# frozen_string_literal: true

module CustomFields
  module Fields
    # Models the definition of single group field, which is a field composed of sub-fields.
    class GroupField < Field
      attr_accessor :fields

      PERMITTED_TYPES = %w[boolean decimal email enum group integer markdown
                           spec string text time_zone url].freeze

      def initialize(key:, fields:)
        super(key: key)
        self.fields = fields.map do |field_data|
          field_data.symbolize_keys!
          type = field_data.delete(:type).to_s
          raise ArgumentError, "Invalid type '#{type}'." unless PERMITTED_TYPES.include?(type)

          klass = "CustomFields::Fields::#{type.classify}Field"
          klass.constantize.new(**field_data)
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
