# frozen_string_literal: true

require "rails_helper"

describe Gather::LocalizedNumber do
  def normalize(value, locale)
    I18n.with_locale(locale) { described_class.normalize(value) }
  end

  it "reads English-style numbers" do
    expect(normalize("12.50", :en)).to eq("12.50")
    expect(normalize("1,234.50", :en)).to eq("1234.50")
    expect(normalize("1,234", :en)).to eq("1234")
    expect(normalize("-3.25", :en)).to eq("-3.25")
  end

  it "reads French-style numbers, including the spaces French groups thousands with" do
    expect(normalize("12,50", :fr)).to eq("12.50")
    expect(normalize("1 234,50", :fr)).to eq("1234.50")
    expect(normalize("1 234,50", :fr)).to eq("1234.50")
    expect(normalize("1 234", :fr)).to eq("1234")
    expect(normalize("-3,25", :fr)).to eq("-3.25")
  end

  it "takes a lone point as the decimal point where it isn't the thousands separator" do
    expect(normalize("12.50", :fr)).to eq("12.50")
    expect(normalize("1.234", :fr)).to eq("1.234")
    expect(normalize("12,5", :en)).to eq("12.5")
  end

  it "takes a point as the thousands separator where it is one" do
    expect(normalize("1.234", :de)).to eq("1234")
    expect(normalize("1.234,50", :de)).to eq("1234.50")
    expect(normalize("12.50", :de)).to eq("12.50")
  end

  it "leaves non-numeric and non-String values alone" do
    expect(normalize("abc", :fr)).to eq("abc")
    expect(normalize("", :fr)).to eq("")
    expect(normalize(nil, :fr)).to be_nil
    expect(normalize(BigDecimal("1.5"), :fr)).to eq(BigDecimal("1.5"))
  end

  describe "decimal attribute casting" do
    it "reads the current locale's style for model columns and form attributes" do
      I18n.with_locale(:fr) do
        expect(Billing::Transaction.new(value: "1 234,50").value).to eq(BigDecimal("1234.50"))
        expect(Meals::Cost.new(ingredient_cost: "12,50").ingredient_cost).to eq(BigDecimal("12.50"))
      end
      I18n.with_locale(:en) do
        expect(Billing::Transaction.new(value: "1,234.50").value).to eq(BigDecimal("1234.50"))
        expect(Billing::Account.new(credit_limit: "").credit_limit).to be_nil
      end
    end
  end

  describe "CurrencyPercentageNormalizer" do
    it "reads amounts and percentages in the current locale's style" do
      I18n.with_locale(:fr) do
        expect(CurrencyPercentageNormalizer.normalize("2,11 $")).to eq(2.11)
        expect(CurrencyPercentageNormalizer.normalize("82,5 %", pct: true)).to eq(0.825)
      end
      I18n.with_locale(:en) do
        expect(CurrencyPercentageNormalizer.normalize("$2.11")).to eq(2.11)
        expect(CurrencyPercentageNormalizer.normalize("82%", pct: true)).to eq(0.82)
      end
    end
  end

  describe "custom field decimals" do
    it "reads the current locale's style" do
      field = CustomFields::Fields::DecimalField.new(key: :amount)
      I18n.with_locale(:fr) { expect(field.normalize("3,50")).to eq(3.5) }
    end
  end
end
