# frozen_string_literal: true

require "rails_helper"

describe "custom field declaration" do
  describe "getters and setters" do
    let(:fake) { FakeCustomFieldModel.new }

    it "should return empty instance if nothing is set" do
      expect(fake.settings.class).to eq(CustomFields::Instance)
      expect(fake.settings.info.complete).to be_nil
    end

    it "should allow initial assignment of full hash" do
      fake.settings = {fruit: "apple", info: {complete: true}}
      expect(fake.settings.class).to eq(CustomFields::Instance)
      expect(fake.settings.fruit).to eq("apple")
      expect(fake.settings.info.complete).to be(true)
      expect(fake.settings.info.comment).to be_nil
    end

    it "should allow update of full hash" do
      fake.settings = {fruit: "apple", info: {complete: true}}
      fake.settings = {fruit: "banana", info: {complete: false}}
      expect(fake.settings.fruit).to eq("banana")
      expect(fake.settings.info.complete).to be(false)
      expect(fake.settings.info.comment).to be_nil
    end

    it "should allow initial assignment of top level value" do
      fake.settings.fruit = "apple"
      expect(fake.settings.fruit).to eq("apple")
    end

    it "should allow initial assignment of lower level value" do
      fake.settings.info.comment = "Hip!"
      expect(fake.settings.info.comment).to eq("Hip!")
    end
  end

  describe "for ActiveRecord model" do
    let(:fake) { FakeCustomFieldActiveRecordModel.new }

    before do
      FakeCustomFieldActiveRecordModel.create_table
    end

    it "should properly store and allow updates to values if none exist to begin with" do
      fake.settings = {"fruit" => "apple", info: {complete: true}}
      fake.settings.info.comment = "Yo!"
      expect(fake.read_attribute(:settings)).to eq(
        "fruit" => "apple", "info" => {"complete" => true, "comment" => "Yo!"}
      )
      fake.save!
      reloaded = FakeCustomFieldActiveRecordModel.find(fake.id)
      expect(reloaded.settings.fruit).to eq("apple")
      expect(reloaded.settings.info.complete).to be(true)
      expect(reloaded.settings.info.comment).to eq("Yo!")
    end

    it "should respect and allow updates to initial values if they exist" do
      fake.write_attribute(:settings, "fruit" => "banana", "info" => {"complete" => false})
      expect(fake.settings.fruit).to eq("banana")
      expect(fake.settings.info.complete).to be(false)
      expect(fake.settings.info.comment).to be_nil
      fake.settings.info.comment = "Yo!"
      expect(fake.read_attribute(:settings)).to eq(
        "fruit" => "banana", "info" => {"complete" => false, "comment" => "Yo!"}
      )
    end

    it "should properly save piecemeal updates" do
      fake.settings = {"fruit" => "apple", info: {complete: true}}
      fake.save!
      fake.settings.fruit = "peach"
      fake.settings.info.comment = "Yo!"
      fake.save!
      reloaded = FakeCustomFieldActiveRecordModel.find(fake.id)
      expect(reloaded.settings.fruit).to eq("peach")
      expect(reloaded.settings.info.complete).to be(true)
      expect(reloaded.settings.info.comment).to eq("Yo!")
    end

    it "should properly save full updates" do
      fake.settings = {"fruit" => "apple", info: {complete: true}}
      fake.save!
      fake.settings = {"fruit" => "apple", info: {complete: false}}
      fake.save!
      reloaded = FakeCustomFieldActiveRecordModel.find(fake.id)
      expect(reloaded.settings.fruit).to eq("apple")
      expect(reloaded.settings.info.complete).to be(false)
    end

    it "should handle nil initial value" do
      fake.write_attribute(:settings, nil)
      expect(fake.settings.fruit).to be_nil
      expect(fake.settings.info.comment).to be_nil
      fake.settings.fruit = "peach"
      fake.settings.info.comment = "Yo!"
      expect(fake.settings.fruit).to eq("peach")
      expect(fake.settings.info.comment).to eq("Yo!")
    end

    it "reload should reload custom fields" do
      fake.settings = {"fruit" => "apple"}
      fake.foo = "alpha"
      fake.save!

      fake2 = FakeCustomFieldActiveRecordModel.find(fake.id)
      fake2.settings.fruit = "peach"
      fake2.foo = "bravo"
      fake2.save!

      fake.reload
      expect(fake.foo).to eq("bravo")
      expect(fake.settings.fruit).to eq("peach")
    end
  end

  describe "validation" do
    context "with model that supports validation" do
      let(:fake) { FakeCustomFieldModel.new }

      it "should set :invalid error on attribute" do
        fake.settings.fruit = "bread"
        expect(fake.valid?).to be(false)
        expect(fake.errors[:settings]).to eq(["is invalid"])
        expect(fake.settings.errors[:fruit]).to eq(["is not included in the list"])
      end
    end

    context "with model that doesn't support validation" do
      let(:fake) { FakeCustomFieldModelNoValidation.new }

      it "should not set any validation errors" do
        fake.settings.fruit = %w[bread]
        expect { fake.valid? }.to raise_error(NoMethodError)
        expect { fake.errors[:settings] }.to raise_error(NoMethodError)
        expect(fake.settings.errors[:fruit]).to eq([])
      end
    end
  end

  describe "i18n keys" do
    let(:fake) { FakeCustomFieldModel.new }

    before do
      I18n.backend.send(:init_translations)
      fake.settings.info.comment = "xxxxxx"
    end

    after do
      I18n.backend = I18n::Backend::Simple.new
    end

    it "should look up main atrrib error msg in right place" do
      I18n.backend.store_translations(:en,
                                      activemodel: {errors: {models: {fake_custom_field_model: {attributes: {settings: {invalid: "m1"}}}}}})
      expect(fake.valid?).to be(false)
      expect(fake.errors[:settings]).to eq(["m1"])
    end

    it "should look up field error msg in right place" do
      I18n.backend.store_translations(:en,
                                      custom_fields: {errors: {fake_custom_field_model: {settings: {info: {comment: {foo: "m2"}}}}}})
      expect(fake.valid?).to be(false)
      expect(fake.settings.info.errors[:comment]).to eq(["m2"])
    end
  end
end
