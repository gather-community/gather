require "rails_helper"

describe CustomFields::Fields::BooleanField do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should convert empty string to nil" do
      expect(field.normalize("")).to be_nil
    end

    it "should convert whitespace to nil" do
      expect(field.normalize("  \n\t ")).to be_nil
    end

    it "should convert weird stuff to nil" do
      expect(field.normalize("foo")).to be_nil
    end

    it "should convert 1 to true and 0 to false" do
      expect(field.normalize("1")).to be true
      expect(field.normalize(1)).to be true
      expect(field.normalize("0")).to be false
      expect(field.normalize(0)).to be false
    end

    it "should convert true and false strings to booleans" do
      expect(field.normalize("true")).to be true
      expect(field.normalize("false")).to be false
    end

    it "should leave literal booleans and nil alone" do
      expect(field.normalize(true)).to be true
      expect(field.normalize(false)).to be false
      expect(field.normalize(nil)).to be_nil
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { true }).to eq({input_html: {checked: true}})
    end
  end
end
