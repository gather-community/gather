# frozen_string_literal: true

module CustomFields
  # Abstract class. Models a concrete set of chosen config values for a given ConfigSpec.
  class Instance
    include ActiveModel::Model

    attr_accessor :spec, :root, :host

    delegate :fields, to: :spec
    delegate :hash, :entries, :entries_by_key, :[], :[]=,
             :label, :hint, :translate, :errors, :input_params, :attrib_name, to: :root

    def initialize(spec:, host:, instance_data:, model_i18n_key:, attrib_name:)
      raise ArgumentError, "instance_data is required" if instance_data.nil?

      self.spec = spec
      self.host = host
      return if undefined?

      self.root = Entries::RootEntry.new(
        parent: self,
        field: spec.root,
        hash: instance_data.deep_symbolize_keys,
        model_i18n_key: model_i18n_key,
        attrib_name: attrib_name
      )

      # Define these methods to pass through to the RootEntry.
      # Nearly identical definitions appear in GroupEntry. We have to duplicate them here
      # because Instance also behaves like an Entry.
      spec.root.fields.each do |f|
        if respond_to?(f.key) || respond_to?("#{f.key}?") || respond_to?("#{f.key}=")
          raise ArgumentError, "`#{f.key}` is a reserved attribute name"
        end

        define_singleton_method(f.key) { root[f.key] }
        define_singleton_method("#{f.key}?") { root[f.key] } if f.type == :boolean
        define_singleton_method("#{f.key}=") { |value| root[f.key] = value }
      end

      notify_of_update
    end

    def undefined?
      spec.empty?
    end

    def key
      attrib_name
    end

    def model_name
      @model_name ||= ActiveModel::Name.new(self.class, nil, attrib_name.to_s)
    end

    # Updates the full hash (as with submitted hash of params).
    def update(new_hash)
      return if root.nil?

      # We set notify to true because we need to treat this update just like all the others initiated by user.
      # This will cause the notify_of_update to run and write out the new hash value to the attribute,
      # if applicable.
      root.update(new_hash, notify: true)
    end

    # If we are on a regular PORO, updates to the hash happen automatically because the reference is
    # passed down. If we are on an AR model though, we need to explicitly call write_attribute when
    # the hash is updated b/c AR seems to store a copy of the hash, not the referenced one.
    def notify_of_update
      host.write_attribute(attrib_name, hash) if host.respond_to?(:write_attribute)
    end

    # This is so that form point to update instead of create
    def persisted?
      true
    end

    def valid?
      return true if undefined?

      root.valid?
    end

    # Returns a list of permitted keys in the form expected by strong params.
    def permitted
      return nil if undefined?

      {attrib_name => spec.permitted}
    end
  end
end
