# frozen_string_literal: true

require "rails_helper"

describe MoneyHelper do
  describe "#format_money" do
    let(:community) { create(:community, country_code: country_code) }
    let(:country_code) { "US" }

    # In the app, current_community comes from the controller or mailer.
    before do
      cmty = community
      helper.define_singleton_method(:current_community) { cmty }
    end

    def format(amount, locale, **options)
      I18n.with_locale(locale) { helper.format_money(amount, **options) }
    end

    it "matches the old number_to_currency output for US communities in English" do
      expect(format(1234.5, :en)).to eq("$1,234.50")
      expect(format(-5, :en)).to eq("-$5.00")
      expect(format(0.1234, :en)).to eq("$0.12")
    end

    context "with a Canadian community" do
      let(:country_code) { "CA" }

      it "uses the community's currency and the locale's separators and symbol position" do
        expect(format(12.5, :en)).to eq("$12.50")
        expect(format(1234.5, :fr)).to eq("1 234,50 $")
        expect(format(1234.5, :fr)).not_to include("€")
      end
    end

    context "with a French community viewed in English" do
      let(:country_code) { "FR" }

      it "shows euros" do
        expect(format(12.5, :en)).to eq("€12.50")
      end
    end

    context "with a community whose country Stripe doesn't support" do
      let(:country_code) { "NG" }

      it "still uses the country's currency" do
        expect(format(12.5, :en)).to eq("₦12.50")
      end
    end

    it "takes an explicit currency" do
      expect(format(12.5, :en, currency: "gbp")).to eq("£12.50")
    end

    it "raises with no current community and no explicit currency" do
      helper.define_singleton_method(:current_community) { nil }
      expect { format(12.5, :en) }.to raise_error(ArgumentError)
      expect(format(12.5, :en, currency: "usd")).to eq("$12.50")
    end

    it "returns nil for nil and an HTML-safe string otherwise" do
      expect(format(nil, :en)).to be_nil
      expect(format(1, :en)).to be_html_safe
    end
  end
end
