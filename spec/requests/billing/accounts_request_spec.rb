# frozen_string_literal: true

require "rails_helper"

# The household's own account page moved from /accounts/yours to /accounts/mine. Statement emails
# people have already received link to the old path, so it must keep working.
describe "accounts request" do
  describe "legacy /accounts/yours path" do
    it "redirects permanently to /accounts/mine" do
      get("/accounts/yours")
      expect(response).to have_http_status(:moved_permanently)
      expect(URI(response.location).path).to eq("/accounts/mine")
    end

    it "keeps the community param" do
      get("/accounts/yours?community=12")
      expect(URI(response.location).path).to eq("/accounts/mine")
      expect(URI(response.location).query).to eq("community=12")
    end
  end
end
