module CustomFields
  # Models a concrete choice made by the user for a particular config Field.
  class Entry
    attr_accessor :field, :value

    delegate :key, :type, :required, :options, :input_params, to: :field

    def initialize(field:, value:)
      self.field = field
      self.value = value
    end
  end
end
