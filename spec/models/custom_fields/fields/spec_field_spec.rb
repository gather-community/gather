# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Fields::SpecField do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should trim whitespace and standardize quotes" do
      expect(field.normalize(%(a: 1   \nb: "2" ))).to eq(%(a: 1\nb: '2'))
    end

    it "should leave other stuff alone" do
      expect(field.normalize(%(a: 1))).to eq(%(a: 1))
      expect(field.normalize(nil)).to be_nil
    end

    it "should leave invalid YAML alone" do
      expect(field.normalize(%(a: 1\n   b: 2))).to eq(%(a: 1\n   b: 2))
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { %(a: 1) }).to eq(input_html: {value: %(a: 1)})
    end
  end
end
