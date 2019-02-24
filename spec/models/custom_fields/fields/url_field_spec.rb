require "rails_helper"

describe CustomFields::Fields::UrlField do
  let(:field) { described_class.new(key: "foo") }

  describe "normalization" do
    it "should strip whitespace" do
      expect(field.normalize("  https://junk.com ")).to eq("https://junk.com")
    end

    it "should leave other stuff alone" do
      # Invalid email should be caught by validation
      expect(field.normalize(nil)).to be_nil
      expect(field.normalize("pants")).to eq "pants"
    end
  end

  describe "value_input_param" do
    it "should return input_param hash" do
      expect(field.value_input_param { "bar" }).to eq(input_html: {value: "bar"})
    end
  end
end
