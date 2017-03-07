require 'rails_helper'

RSpec.describe Configurator::Entry, type: :model do
  let(:field) { Configurator::Fields::EnumField.new(key: "foo", options: %w(a b), required: true) }
  let(:entry) { described_class.new(field: field, value: "b") }

  it "should delegate field methods" do
    expect(entry.key).to eq field.key
    expect(entry.type).to eq field.type
    expect(entry.options).to eq field.options
    expect(entry.required).to be field.required
    expect(entry.input_params).to eq field.input_params
  end
end
