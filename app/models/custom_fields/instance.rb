module CustomFields
  # Abstract class. Models a concrete set of chosen config values for a given ConfigSpec.
  class Instance
    include ActiveModel::Model

    attr_accessor :spec, :root

    delegate :fields, to: :spec
    delegate :hash, :entries, :entries_by_key, :update, :[], :[]=, :valid?, :errors, to: :root

    def initialize(spec:, instance_data:, model_i18n_key:, attrib_name:)
      raise ArgumentError.new("instance_data is required") if instance_data.nil?
      self.spec = spec
      self.root = Entries::RootEntry.new(
        field: spec.root,
        hash: instance_data,
        model_i18n_key: model_i18n_key,
        attrib_name: attrib_name
      )
    end

    # This is so that form point to update instead of create
    def persisted?
      true
    end

    def method_missing(symbol, *args)
      if root.keys.include?(symbol.to_s.chomp("=").to_sym)
        root.send(symbol, *args)
      else
        super
      end
    end
  end
end
