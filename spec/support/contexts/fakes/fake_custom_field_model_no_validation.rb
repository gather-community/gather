# frozen_string_literal: true

class FakeCustomFieldModelNoValidation
  include CustomFields

  custom_fields :settings, spec: [
    {key: "fruit", type: "enum", options: %w[apple banana peach], required: true}
  ]

  def self.test_mock?
    true
  end
end
