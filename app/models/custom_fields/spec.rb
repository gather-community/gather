module CustomFields
  # Models a specification for an object's config. Made up of Fields.
  class Spec
    attr_accessor :root

    delegate :items, :keys, to: :root

    # Accepts a JSON-originating array of hashes defining the spec.
    # Converts to Field objects.
    def initialize(spec_data)
      raise ArgumentError.new("spec data is required") if spec_data.nil?
      self.root = Fields::GroupField.new(key: :__root__, items: spec_data)
    end
  end
end
