require 'rails_helper'

RSpec.describe "custom field declaration", type: :model do
  let(:fake) { FakeCustomFieldModel.new }

  describe "getters and setters" do
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

    it "should allow initial assignment of top level value" do
      fake.settings.fruit = "apple"
      expect(fake.settings.fruit).to eq "apple"
    end

    it "should allow initial assignment of lower level value" do
      fake.settings.info.comment = "Hip!"
      expect(fake.settings.info.comment).to eq "Hip!"
    end
  end

  describe "for ActiveRecord model" do
    let(:fake) { FakeCustomFieldActiveRecordModel.new }

    it "should properly store and allow updates to values if none exist to begin with" do
      fake.settings = {"fruit" => "apple", info: {complete: true}}
      fake.settings.info.comment = "Yo!"
      expect(fake.read_attribute(:settings)).to eq({fruit: "apple", info: {complete: true, comment: "Yo!"}})
    end

    it "should respect and allow updates to initial values if they exist" do
      fake.write_attribute(:settings, {"fruit" => "banana", "info" => {"complete" => false}})
      expect(fake.settings.fruit).to eq "banana"
      expect(fake.settings.info.complete).to be false
      expect(fake.settings.info.comment).to be_nil
      fake.settings.info.comment = "Yo!"
      expect(fake.read_attribute(:settings)).to eq({fruit: "banana", info: {complete: false, comment: "Yo!"}})
    end

    it "should handle nil initial value" do
      fake.write_attribute(:settings, nil)
      expect(fake.settings.fruit).to be_nil
      expect(fake.settings.info.comment).to be_nil
      fake.settings.fruit = "peach"
      fake.settings.info.comment = "Yo!"
      expect(fake.settings.fruit).to eq "peach"
      expect(fake.settings.info.comment).to eq "Yo!"
    end
  end
end
