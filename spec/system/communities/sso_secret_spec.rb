# frozen_string_literal: true

require "rails_helper"

describe "single sign-on secret", js: true do
  let(:community) { Defaults.community }

  before do
    community.update!(sso_secret: "oldsecret")
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as admin" do
    let(:actor) { create(:admin) }

    scenario "view, show/hide, and reset" do
      visit("/settings/community")
      expect(page).to have_content("Single Sign On")
      click_link("View/Reset Secret")

      expect(page).to have_title("Single Sign On Secret")
      field = find_field("Single sign-on secret", type: "password")
      expect(field.value).to eq("oldsecret")

      click_button("Show")
      expect(page).to have_field("Single sign-on secret", type: "text", with: "oldsecret")
      click_button("Hide")
      expect(page).to have_field("Single sign-on secret", type: "password")

      click_link("Reset Secret")
      expect_modal(text: "Reset the secret?")
      click_modal_button("Reset Secret")
      expect(page).to have_content("The single sign-on secret was reset.")

      new_secret = community.reload.sso_secret
      expect(new_secret).not_to eq("oldsecret")
      expect(find_field("Single sign-on secret", type: "password").value).to eq(new_secret)
    end
  end
end
