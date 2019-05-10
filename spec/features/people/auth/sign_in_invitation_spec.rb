# frozen_string_literal: true

require "rails_helper"

feature "sign in invitations", js: true do
  let(:actor) { create(:admin) }
  let(:email_sent) { email_sent_by { process_queued_job } }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  describe "google oauth happy path" do
    let!(:invitee) { create(:user, :unconfirmed, first_name: "Bob", last_name: "Flob", google_email: nil) }
    let!(:decoy) { create(:user) }

    around do |example|
      stub_omniauth(google_oauth2: {email: "bob1234flob@gmail.com"}) { example.run }
    end

    it do
      expect(invitee).not_to be_confirmed
      full_sign_in_as(actor)
      visit(user_path(invitee))
      accept_confirm { click_on("Invite") }
      expect_success(/Invitation sent./)
      full_sign_out

      # Get the link from the email and visit it.
      expect(email_sent.size).to eq(1)
      url_regex = %r{https?://.+/?token=.+$}
      body = email_sent.last.body.encoded
      expect(body).to match(/Bob Flob/)
      match_and_visit_url(body, url_regex)

      # Sign in with Google.
      # If the user's google email has been updated, we know the token process worked as expected.
      click_link("Sign in with Google")
      expect(page).to have_signed_in_user(invitee)
      expect(invitee.reload.google_email).to eq("bob1234flob@gmail.com")
      expect(invitee).to be_confirmed
    end
  end

  describe "password happy path" do
    let!(:invitee) { create(:user, :unconfirmed, first_name: "Bob", last_name: "Flob") }
    let!(:decoy) { create(:user) }

    it do
      expect(invitee).not_to be_confirmed
      full_sign_in_as(actor)
      visit(user_path(invitee))
      accept_confirm { click_on("Invite") }
      expect_success(/Invitation sent./)
      full_sign_out

      # Get the link from the email and visit it.
      expect(email_sent.size).to eq(1)
      url_regex = %r{https?://.+/?token=.+$}
      body = email_sent.last.body.encoded
      expect(body).to match(/Bob Flob/)
      match_and_visit_url(body, url_regex)

      click_link("Sign in with Password")
      click_link("Don't know your password")
      expect(page).to have_title("Enter a New Password")
      fill_in("New Password", with: "48hafeirafar42", match: :prefer_exact)
      fill_in("Re-type New Password", with: "48hafeirafar42")
      click_on("Reset Password")
      expect(page).to have_alert("Your password has been changed successfully. You are now signed in.")
      expect(invitee.reload).to be_confirmed
    end
  end

  describe "bulk send" do
    let!(:invitee1) { create(:user, sign_in_count: 10) }
    let!(:invitee2) { create(:user, first_name: "Bob", last_name: "Flob", google_email: nil) }
    let!(:invitee3) { create(:user, first_name: "Squib", last_name: "Flib") }
    let!(:decoy) { create(:user, :inactive) }

    before { login_as(actor, scope: :user) }

    scenario do
      visit(users_path)
      find(".top-buttons .btn-primary.dropdown-toggle").click
      click_on("Invite To Sign In")

      # Expect question icons on correct users.
      within(find(:xpath, "//label[text()[contains(., '#{invitee2.name}')]]")) do
        expect(page).to have_css("i.fa-question-circle")
      end
      within(find(:xpath, "//label[text()[contains(., '#{invitee1.name}')]]")) do
        expect(page).not_to have_css("i.fa-question-circle")
      end

      click_on("Select All No-Sign-Ins")
      click_button("Send Invitations")
      expect_success(/Invitations sent./)

      expect(email_sent.size).to eq(2)
      expect(email_sent.map(&:to)).to contain_exactly([invitee2.email], [invitee3.email])
    end
  end
end
