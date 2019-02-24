require 'rails_helper'

describe CustomFields::Fields::Field do
  let(:field) { CustomFields::Fields::StringField.new(key: "foo") }

  it "should symbolize string params" do
    expect(field.key).to eq :foo
    expect(field.type).to eq :string
  end

  context "with reserved key" do
    it "should raise error" do
      expect { CustomFields::Fields::StringField.new(key: :entries) }.
        to raise_error(CustomFields::ReservedKeyError)
      expect { CustomFields::Fields::StringField.new(key: "entries") }.
        to raise_error(CustomFields::ReservedKeyError)
    end
  end
end
