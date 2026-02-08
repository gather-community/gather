# frozen_string_literal: true

require "rails_helper"

# See the User class for more documentation on email confirmation.
describe "email reconfirmation", js: true do
  shared_examples_for "email reconfirmation" do
    context "when signed in" do
      before do
        login_as(actor, scope: :user)
      end

      scenario "clicking link in email with valid token" do
        email = email_sent_by { actor.update!(email: "new@example.com") }.first
        match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
        expect(page).to have_alert("Your email address has been successfully confirmed.")
        expect(page).to have_title(actor.name)
        expect(page).to have_content("new@example.com")
        expect(page).not_to have_content("old@example.com")
        expect(page).not_to have_content("Pending confirmation")
      end

      scenario "clicking link in email with expired token" do
        email = Timecop.travel(-10.days) do
          email_sent_by { actor.update!(email: "new@example.com") }.first
        end
        match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
        expect(page).to have_alert("The confirmation period has expired. Please use")
        email = email_sent_by { click_on("Resend confirmation instructions") }.first
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
        expect(page).to have_alert("Your email address has been successfully confirmed. Please sign in")
        click_on("Sign in with Password")
        fill_in("Email Address", with: "new@example.com")
        fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
        click_on("Sign In")
        click_on_personal_nav("Profile")
        expect(page).to have_content("new@example.com")
        expect(page).not_to have_content("old@example.com")
        expect(page).not_to have_content("Pending confirmation")
      end

      scenario "clicking link in email with expired token" do
        email = Timecop.travel(-10.days) do
          email_sent_by { actor.update!(email: "new@example.com") }.first
        end
        match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
        expect(page).to have_alert("The confirmation period has expired. Please sign in")
        click_on("Sign in with Password")
        fill_in("Email Address", with: "old@example.com")
        fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
        click_on("Sign In")
        click_on_personal_nav("Profile")
        email = email_sent_by do
          click_on("Resend confirmation instructions")
          expect(page).to have_content("Instructions sent")
        end.first
        match_and_visit_url(email.body.encoded, %r{https?://.+/?confirmation_token=.+$})
        expect(page).to have_alert("Your email address has been successfully confirmed.")
        expect(page).to have_title(actor.name)
        expect(page).to have_content("new@example.com")
        expect(page).not_to have_content("old@example.com")
        expect(page).not_to have_content("Pending confirmation")
      end
    end
  end

  context "as adult" do
    let(:actor) { create(:user, email: "old@example.com") }
    it_behaves_like "email reconfirmation"
  end

  context "as full_access_child" do
    let(:actor) { create(:user, :full_access_child, email: "old@example.com") }
    it_behaves_like "email reconfirmation"
  end

  context "when editing directory-only child" do
    let(:actor) { create(:user) }
    let!(:child) { create(:user, :child, email: "kid@example.com", guardians: [actor]) }

    before do
      use_user_subdomain(child)
      login_as(actor, scope: :user)
    end

    scenario "should allow change without reconfirmation" do
      expect do
        visit(edit_user_path(child))
        fill_in("Email Address", with: "kid2@example.com")
        click_on("Save")
        expect(page).to have_content("kid2@example.com")
        expect(page).not_to have_content("kid@example.com")
        expect(page).not_to have_content("Pending confirmation")
      end.not_to(change { ActionMailer::Base.deliveries.size })
    end
  end
end
