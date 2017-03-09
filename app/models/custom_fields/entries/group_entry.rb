module CustomFields
  module Entries
    # A set of Entrys corresponding to a GroupField in the Spec.
    class GroupEntry < Entry
      attr_accessor :entries

      def initialize(field:, hash:)
        super(field: field, hash: hash)
        self.entries = field.fields.map do |f|
          klass = f.type == :group ? GroupEntry : Entry
          klass.new(field: f, hash: value)
        end
      end

      def value
        # If this is the root GroupEntry, the value is just the hash itself
        field.root? ? hash : super
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

      def update(hash)
        hash = hash.with_indifferent_access
        entries.each do |entry|
          entry.update(hash[entry.key]) if hash.has_key?(entry.key)
        end
      end

      private

      def entries_by_key
        @entries_by_key ||= entries.map { |e| [e.key, e] }.to_h
      end
    end
  end
end
