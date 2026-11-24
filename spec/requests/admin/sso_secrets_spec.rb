# frozen_string_literal: true

require "rails_helper"

describe "single sign-on secret" do
  let(:community) { Defaults.community }

  before do
    community.update!(sso_secret: "oldsecret")
    use_user_subdomain(actor)
    sign_in(actor)
  end

  context "as admin" do
    let(:actor) { create(:admin) }

    it "links to the secret page from the settings page" do
      get("/admin/settings/community")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_sso_secret_path)
    end
  end

  context "as regular user" do
    let(:actor) { create(:user) }

    it "forbids viewing the secret" do
      expect { get(admin_sso_secret_path) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids resetting the secret" do
      expect { put(reset_admin_sso_secret_path) }.to raise_error(Pundit::NotAuthorizedError)
      expect(community.reload.sso_secret).to eq("oldsecret")
    end
  end
end
