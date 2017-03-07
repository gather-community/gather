module CustomFields
  # Abstract class. Models a concrete set of chosen config values for a given ConfigSpec.
  class Config
    include ActiveModel::Model

    attr_accessor :spec, :config_data, :entries, :keys

    delegate :items, to: :spec

    # def self.model_name
    #   ActiveModel::Name.new(self, nil, name.split("::").last)
    # end
    #
    # Accepts a ConfigSpec object and a JSON-originating hash of chosen values.
    def initialize(spec_data:, config_data:)
      raise ArgumentError.new("config_data is required") if config_data.nil?
      self.spec = Spec.new(spec_data)
      self.config_data = config_data.symbolize_keys!
      self.entries = items.map { |i| Entry.new(field: i, value: self.config_data[i.key]) }
    end

    # This is so that form point to update instead of create
    def persisted?
      true
    end

    def update(hash)
      hash = hash.with_indifferent_access
      # Iterate through and update the existing hash.
      spec.keys.each do |key, value|
        config_data[key] = hash[key] if hash.has_key?(key)
      end
    end

    def method_missing(symbol, *args)
      if spec.keys.include?(symbol)
        self[symbol]
      else
        super
      end
    end

    def [](key)
      config_data[key.to_sym]
    end
  end
end
