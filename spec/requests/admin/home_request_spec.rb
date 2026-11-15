# frozen_string_literal: true

require "rails_helper"

describe "admin home request" do
  before do
    use_apex_domain
    sign_in(actor)
  end

  context "as super admin" do
    let(:actor) { create(:super_admin) }

    it "redirects to the communities page" do
      get admin_home_path
      expect(response).to redirect_to(admin_communities_path)
    end

    it "renders operator pages in English whatever language the user chose" do
      create(:feature_flag, name: "i18n", status: true)
      cookies[Gather::Locales::COOKIE] = "de"
      get admin_communities_path
      expect(response.body).to include('<html lang="en"')
      expect(response.body).to include("Return to Main Site")
    end
  end

  context "as new community approver" do
    let(:actor) { create(:user).tap { |u| u.add_role(:new_community_approver) } }

    it "redirects to the signups page, the only operator page they can see" do
      get admin_home_path
      expect(response).to redirect_to(admin_signups_path)
    end
  end

  context "as community admin" do
    let(:actor) { create(:admin) }

    it "is denied" do
      expect { get admin_home_path }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
