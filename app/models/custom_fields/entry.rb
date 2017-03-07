module CustomFields
  # Models a concrete choice made by the user for a particular config Field.
  class Entry
    attr_accessor :field, :value, :entries

    delegate :key, :type, :required, :options, :input_params, to: :field

    def initialize(field:, value:)
      self.field = field
      self.value = value
      if type == :group
        value ||= {}
        value.symbolize_keys!
        self.entries = field.fields.map { |f| Entry.new(field: f, value: value[f.key]) }
      end
    end

    def keys
      entries_by_key.keys
    end

    def [](key)
      raise NotImplementedError unless type == :group
      return nil unless entry = entries_by_key[key.to_sym]
      entry.type == :group ? entry : entry.value
    end

    def method_missing(symbol, *args)
      if type == :group && keys.include?(symbol)
        self[symbol]
      else
        super
      end
    end

    private

    def entries_by_key
      @entries_by_key ||= entries.map { |e| [e.key, e] }.to_h
    end
  end
end
