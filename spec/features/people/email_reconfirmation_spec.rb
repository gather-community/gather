# frozen_string_literal: true

require "rails_helper"

feature "email reconfirmation", js: true do
  let(:actor) { create(:user, email: "old@example.com") }

  context "when signed in" do
    before do
      login_as(actor, scope: :user)
    end

    scenario "clicking link in email" do
      email = email_sent_by { actor.update!(email: "new@example.com") }.first
      match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
      expect(page).to have_alert("Your email address has been successfully confirmed.")
      expect(page).to have_title(actor.name)
      expect(page).to have_content("new@example.com")
      expect(page).not_to have_content("old@example.com")
      expect(page).not_to have_content("Pending confirmation")
    end
  end

  context "when not signed in" do
    scenario "clicking link in email" do
      email = email_sent_by { actor.update!(email: "new@example.com") }.first
      match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
      expect(page).to have_alert("Your email address has been successfully confirmed."\
        " Please sign in to use Gather.")
      click_on("Sign in with Password")
      fill_in("Email", with: "new@example.com")
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      click_on("Sign In")
      click_on_personal_nav("Profile")
      expect(page).to have_content("new@example.com")
      expect(page).not_to have_content("old@example.com")
      expect(page).not_to have_content("Pending confirmation")
    end
  end
end
