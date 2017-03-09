module CustomFields
  module Entries
    # A set of Entrys corresponding to a GroupField in the Spec.
    class GroupEntry < Entry
      attr_accessor :entries

      def initialize(field:, value:)
        value ||= {}
        value.symbolize_keys!
        self.entries = field.fields.map do |f|
          klass = f.type == :group ? GroupEntry : Entry
          klass.new(field: f, value: value[f.key])
        end
        super(field: field, value: value)
      end

      def keys
        entries_by_key.keys
      end

      def [](key)
        return nil unless entry = entries_by_key[key.to_sym]
        entry.type == :group ? entry : entry.value
      end

      def method_missing(symbol, *args)
        keys.include?(symbol) ? self[symbol] : super
      end

      private

      def entries_by_key
        @entries_by_key ||= entries.map { |e| [e.key, e] }.to_h
      end
    end
  end
end
