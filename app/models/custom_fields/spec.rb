# frozen_string_literal: true

module CustomFields
  # Models a specification for an object's config. Made up of Fields.
  class Spec
    attr_accessor :root

    delegate :fields, :permitted, to: :root

    # Accepts a JSON-originating array of hashes defining the spec.
    # Converts to Field objects.
    def initialize(spec_data)
      return if spec_data.nil?

      self.root = Fields::GroupField.new(key: :__root__, fields: spec_data)

      # Create a dummy instance to ensure that no reserved name collisions are encountered.
      Instance.new(spec: self, host: self, instance_data: {}, model_i18n_key: "foo", attrib_name: "sample")
    end

    def empty?
      root.nil?
    end
  end
end
