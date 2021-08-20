# frozen_string_literal: true

require "rails_helper"

describe "communities", js: true do
  let(:actor) { create(:super_admin) }
  let!(:community) { create(:community, name: "Funton Coho") }

  before do
    login_as(actor, scope: :user)
  end

  context "with no subdomain" do
    it "works" do
      visit(communities_path)
      expect(page).to have_content("Funton Coho")
    end
  end

  context "with subdomain" do
    before do
      use_user_subdomain(actor)
    end

    it "works" do
      visit(communities_path)
      expect(page).to have_content("Funton Coho")
      expect(page).to have_content("Meals")
    end
  end
end
