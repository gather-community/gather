require 'rails_helper'

describe CustomFields::Fields::TimeZoneField do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should leave other stuff alone" do
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { "Saskatchewan" }).to eq({selected: "Saskatchewan"})
    end
  end
end
