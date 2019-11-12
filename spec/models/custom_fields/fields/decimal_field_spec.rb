# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Fields::DecimalField do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should convert strings to decimals" do
      expect(field.normalize(" 85 ")).to eq(85.0)
      expect(field.normalize(" -123.12  ")).to eq(-123.12)
      expect(field.normalize(" 0  ")).to eq(0.0)
      expect(field.normalize(" -0.0  ")).to eq(0.0)
    end

    it "should leave other stuff alone" do
      expect(field.normalize(32.4)).to eq(32.4)
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { 123.1 }).to eq(input_html: {value: 123.1})
    end
  end
end
