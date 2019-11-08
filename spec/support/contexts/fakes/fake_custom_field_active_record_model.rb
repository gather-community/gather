class FakeCustomFieldActiveRecordModel < ActiveRecord::Base
  include CustomFields

  custom_fields :settings, spec: [
    {key: "fruit", type: "enum", options: %w(apple banana peach), required: true},
    {key: "info", type: "group", fields: [
      {key: "complete", type: "boolean"},
      {key: "comment", type: "string"}
    ]}
  ]

  def self.create_table
    ActiveRecord::Base.connection.create_table(table_name, force: true) do |t|
      t.column :foo, :string
      t.column :settings, :jsonb
    end
  end

  def self.drop_table
    ActiveRecord::Base.connection.drop_table(table_name)
  end
end
