# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Fields::EnumField do
  let(:field) { described_class.new(key: "foo", options: %w[a b]) }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should leave other stuff alone" do
      # If something doesn't match the options, that should be handled by the validations
      expect(field.normalize("a")).to eq("a")
      expect(field.normalize(" a ")).to eq(" a ")
      expect(field.normalize(" z ")).to eq(" z ")
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { "a" }).to eq(selected: "a")
    end
  end

  describe "additional_input_params" do
    context "without include_blank" do
      it "should pass on include_blank to in additional_input_params" do
        expect(field.additional_input_params).to eq({})
      end
    end

    context "with include_blank" do
      let(:field) { described_class.new(key: "foo", options: %w[a b], include_blank: "Stuff") }

      it "should pass on include_blank to in additional_input_params" do
        expect(field.additional_input_params).to eq(include_blank: "Stuff")
      end
    end
  end

  describe "validation" do
    context "without include_blank" do
      it "should validate for inclusion" do
        expect(field.validation).to eq(inclusion: {in: %w[a b]})
      end
    end

    context "with include_blank" do
      let(:field) { described_class.new(key: "foo", options: %w[a b], include_blank: "Stuff") }

      it "should allow blank" do
        expect(field.validation).to eq(inclusion: {in: %w[a b], allow_blank: true})
      end
    end
  end
end
