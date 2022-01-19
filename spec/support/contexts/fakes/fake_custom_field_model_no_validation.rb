# frozen_string_literal: true

class FakeCustomFieldModelNoValidation
  include CustomFields

  custom_fields :settings, spec: lambda { |_instance|
    [
      {key: "fruit", type: "enum", options: %w[apple banana peach], required: true}
    ]
  }

  def self.test_mock?
    true
  end
end
