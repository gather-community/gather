# frozen_string_literal: true

require "rails_helper"

describe Gather::Locales do
  describe ".preferred_tags" do
    it "orders by quality, then by position, and drops wildcards and q=0" do
      header = "de;q=0.5, fr-CA, en-US;q=0.8, *;q=0.1, es;q=0, fr;q=0.8"
      expect(described_class.preferred_tags(header)).to eq(%w[fr-ca en-us fr de])
    end

    it "handles a blank header" do
      expect(described_class.preferred_tags(nil)).to eq([])
      expect(described_class.preferred_tags("")).to eq([])
    end
  end

  describe ".match" do
    let(:eligible) { %i[en fr fr-CA es nb] }

    it "prefers an exact match over a bare-language match" do
      expect(described_class.match("fr-CA", eligible)).to eq(:"fr-CA")
    end

    it "falls back to the bare language for other regions" do
      expect(described_class.match("fr-BE", eligible)).to eq(:fr)
      expect(described_class.match("es-MX", eligible)).to eq(:es)
      expect(described_class.match("en-US,en;q=0.9", eligible)).to eq(:en)
    end

    it "uses the bare language when a regional locale isn't eligible" do
      expect(described_class.match("fr-CA", %i[en fr])).to eq(:fr)
    end

    it "maps the Norwegian variants to Bokmål" do
      expect(described_class.match("no", eligible)).to eq(:nb)
      expect(described_class.match("nn-NO", eligible)).to eq(:nb)
      expect(described_class.match("nb-NO", eligible)).to eq(:nb)
    end

    it "skips preferences that match nothing" do
      expect(described_class.match("ja, es;q=0.7", eligible)).to eq(:es)
    end

    it "returns nil when nothing matches" do
      expect(described_class.match("ja, zh", eligible)).to be_nil
      expect(described_class.match(nil, eligible)).to be_nil
    end
  end

  describe ".for_request" do
    let(:user) { create(:user) }

    context "without the feature flag" do
      it "serves the default locale to everyone, whatever the header or cookie say" do
        expect(described_class.for_request("fr-CA, fr;q=0.9", user: user)).to eq(:en)
        expect(described_class.for_request("fr-CA", user: nil)).to eq(:en)
        expect(described_class.for_request("en", user: user, chosen: "de")).to eq(:en)
      end
    end

    context "with the feature flag on for everyone" do
      before { create(:feature_flag, name: "i18n", status: true) }

      it "serves the browser's locale, signed in or not" do
        expect(described_class.for_request("fr-CA, fr;q=0.9", user: user)).to eq(:"fr-CA")
        expect(described_class.for_request("de-AT", user: nil)).to eq(:de)
      end

      it "falls back to the default locale when nothing matches" do
        expect(described_class.for_request("ja", user: nil)).to eq(:en)
        expect(described_class.for_request(nil, user: nil)).to eq(:en)
      end

      it "prefers the locale chosen in the language menu" do
        expect(described_class.for_request("fr-CA", user: user, chosen: "sv")).to eq(:sv)
        expect(described_class.for_request(nil, user: nil, chosen: "fr-CA")).to eq(:"fr-CA")
      end

      it "ignores a chosen locale that doesn't exist" do
        expect(described_class.for_request("de", user: user, chosen: "xx")).to eq(:de)
        expect(described_class.for_request("de", user: user, chosen: "")).to eq(:de)
      end
    end

    context "with the feature flag on for some users" do
      let!(:flag) { create(:feature_flag, name: "i18n", interface: "user") }

      before { flag.users << user }

      it "serves other locales to those users" do
        expect(described_class.for_request("fr-CA, fr;q=0.9", user: user)).to eq(:"fr-CA")
        expect(described_class.for_request("en", user: user, chosen: "de")).to eq(:de)
      end

      it "doesn't serve them to other users or signed-out visitors" do
        expect(described_class.for_request("fr-CA", user: create(:user))).to eq(:en)
        expect(described_class.for_request("fr-CA", user: nil, chosen: "fr")).to eq(:en)
      end
    end
  end

  describe ".menu_options" do
    it "names each locale in its own language, sorted for the page's locale" do
      expect(described_class.menu_options).to eq([
        ["Deutsch", "de"], ["English", "en"], ["Español", "es"], ["Français", "fr"],
        ["Français (Canada)", "fr-CA"], ["Italiano", "it"], ["Nederlands", "nl"], ["Norsk bokmål", "nb"],
        ["Suomi", "fi"], ["Svenska", "sv"]
      ])
    end
  end
end
