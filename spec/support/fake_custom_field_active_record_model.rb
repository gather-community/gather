class FakeCustomFieldActiveRecordModel
  include CustomFields
  custom_fields :settings, spec: [
    {key: "fruit", type: "enum", options: %w(apple banana peach), required: true},
    {key: "info", type: "group", fields: [
      {key: "complete", type: "boolean"},
      {key: "comment", type: "string"}
    ]}
  ]

  # Stub AR read/write methods

  def read_attribute(symbol)
    @__attribs__ ||= {}
    @__attribs__[symbol]
  end

  def write_attribute(symbol, value)
    @__attribs__ ||= {}
    @__attribs__[symbol] = value
  end
end
