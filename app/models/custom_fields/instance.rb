module CustomFields
  # Abstract class. Models a concrete set of chosen config values for a given ConfigSpec.
  class Instance
    include ActiveModel::Model

    attr_accessor :spec, :root

    delegate :fields, to: :spec
    delegate :hash, :entries, :entries_by_key, :update, :[], :[]=,
      :valid?, :errors, :input_params, :attrib_name, to: :root

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

    def key
      attrib_name
    end

    def model_name
      @model_name ||= ActiveModel::Name.new(self.class, nil, attrib_name.to_s)
    end

    # This is so that form point to update instead of create
    def persisted?
      true
    end

    # Returns a list of permitted keys in the form expected by strong params.
    def permitted
      {attrib_name => spec.permitted}
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
