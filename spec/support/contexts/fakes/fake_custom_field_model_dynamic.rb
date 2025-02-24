# frozen_string_literal: true

class FakeCustomFieldModelDynamic
  include ActiveModel::Validations
  include CustomFields

  attr_accessor :fruits

  custom_fields :settings, spec: ->(instance) { instance.build_spec }

  def build_spec
    return nil if fruits.nil?

    [
      {key: "fruit", type: "enum", options: fruits, required: true}
    ]
  end

  def self.test_mock?
    true
  end
end
