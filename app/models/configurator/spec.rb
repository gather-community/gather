module Configurator
  # Models a specification for an object's config. Made up of Fields.
  class Spec
    attr_accessor :fields

    # Accepts a JSON-originating array of hashes defining the spec. Converts to FieldSpec objects.
    def initialize(spec_data)
      raise ArgumentError.new("spec data is required") if spec_data.nil?
      self.fields = spec_data.map { |s| Field.new(s.symbolize_keys) }
    end

    def keys
      fields.map(&:key)
    end
  end
end
