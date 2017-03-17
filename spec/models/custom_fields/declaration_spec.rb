require 'rails_helper'

RSpec.describe "custom field declaration", type: :model do
  let(:fake) { FakeCustomFieldModel.new }

  it "should return empty instance if nothing is set" do
    expect(fake.settings.class).to eq CustomFields::Instance
    expect(fake.settings.info.complete).to be_nil
  end

  it "should allow initial assignment of full hash" do
    fake.settings = {fruit: "apple", info: {complete: true}}
    expect(fake.settings.class).to eq CustomFields::Instance
    expect(fake.settings.fruit).to eq "apple"
    expect(fake.settings.info.complete).to be true
    expect(fake.settings.info.comment).to be_nil
  end

  it "should allow update of full hash" do
    fake.settings = {fruit: "apple", info: {complete: true}}
    fake.settings = {fruit: "banana", info: {complete: false}}
    expect(fake.settings.fruit).to eq "banana"
    expect(fake.settings.info.complete).to be false
    expect(fake.settings.info.comment).to be_nil
  end

  it "should allow initial assignment of individual values" do
    fake.settings.fruit = "apple"
    expect(fake.settings.fruit).to eq "apple"
  end

  # TODO
  # Handling of nil base hash
  # Use existing values if exist
  # Validation
  # Invalid spec
  # Correct i18n keys
  # ActiveRecord serializer
end
