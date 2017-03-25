require 'rails_helper'

RSpec.describe CustomFields::Fields::Field, type: :model do
  let(:field) { CustomFields::Fields::StringField.new(key: "foo") }

  it "should symbolize string params" do
    expect(field.key).to eq :foo
    expect(field.type).to eq :string
  end
end
