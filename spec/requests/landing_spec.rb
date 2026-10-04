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
    it "renders the privacy policy" do
      get("/about/privacy-policy")
      expect(response).to have_http_status(200)
      expect(response.body).to include("Service providers")
    end

    it "renders the terms of use" do
      get("/about/terms-of-use")
      expect(response).to have_http_status(200)
      expect(response.body).to include("Acceptable use")
    end

    it "returns 404 for an unknown page" do
      get("/about/phpinfo.php")
      expect(response).to have_http_status(404)
    end
  end
end
