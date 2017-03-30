require 'rails_helper'

RSpec.describe CustomFields::Fields::EnumField, type: :model do
  let(:field) { described_class.new(key: "foo", options: %w(a b)) }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should leave other stuff alone" do
      # If something doesn't match the options, that should be handled by the validations
      expect(field.normalize("a")).to eq "a"
      expect(field.normalize(" a ")).to eq " a "
      expect(field.normalize(" z ")).to eq " z "
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { "a" }).to eq({selected: "a"})
    end
  end
end
