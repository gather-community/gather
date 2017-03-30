require 'rails_helper'

RSpec.describe CustomFields::Fields::IntegerField, type: :model do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should convert strings to integers" do
      expect(field.normalize(" 85 ")).to eq 85
      expect(field.normalize(" -123.12  ")).to eq -123
      expect(field.normalize(" 0  ")).to eq 0
      expect(field.normalize(" -0  ")).to eq 0
    end

    it "should leave other stuff alone" do
      expect(field.normalize(32)).to eq 32
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { 123 }).to eq({input_html: {value: 123}})
    end
  end
end
