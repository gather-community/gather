# frozen_string_literal: true

require "rails_helper"

describe "landing pages" do
  describe "index" do
    it "renders HTML even when JSON is requested" do
      get("/", headers: {"Accept" => "application/json"})
      expect(response).to have_http_status(200)
      expect(response.media_type).to eq("text/html")
    end
  end

  describe "public_static" do
    it "renders a known page" do
      get("/about/privacy-policy")
      expect(response).to have_http_status(200)
    end

    it "returns 404 for an unknown page" do
      get("/about/phpinfo.php")
      expect(response).to have_http_status(404)
    end
  end

  # Pages can't render in another locale until it's translated (tests raise on missing translations), so
  # these pretend English is machine-translated.
  describe "machine translation notice" do
    it "isn't shown for locales people translated" do
      get("/about/privacy-policy")
      expect(response.body).not_to include("translated automatically")
    end

    context "in a machine-translated locale" do
      before { stub_const("Gather::Locales::MACHINE_TRANSLATED", [:en]) }

      it "is shown in the footer, linking to where people can help when that's set" do
        get("/about/privacy-policy")
        expect(response.body).to include("This page was translated automatically and may contain mistakes.")
        expect(response.body).not_to include("Help improve the translation")

        allow(Settings).to receive(:translation_help_url).and_return("https://example.com/translate")
        get("/about/privacy-policy")
        expect(response.body)
          .to include('<a href="https://example.com/translate">Help improve the translation</a>')
      end
    end
  end
end
