# frozen_string_literal: true

require "rails_helper"

# Members change their own Google ID with the "change it" link in the Google ID field's hint on their
# profile form. The link goes through Google sign-in and comes back to the form.
describe "changing own google ID", perform_jobs: true do
  let(:user) { create(:user, google_email: old_google_id) }
  let(:old_google_id) { "old@gmail.com" }
  let(:new_google_id) { "new@gmail.com" }

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = mock_auth
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "when Google returns an account" do
    let(:mock_auth) { OmniAuth::AuthHash.new(uid: "12345", info: {email: new_google_id}) }

    it "links the new account, emails the member, and returns to the form" do
      emails = email_sent_by { change_google_id }
      expect(page).to have_alert("You'll now sign in to Gather with the Google account new@gmail.com.")
      expect(page).to have_field("Google ID", with: "new@gmail.com", disabled: true)
      expect(page).to have_current_path(edit_user_path(user))
      expect(page).to have_signed_in_user(user)

      user.reload
      expect(user.google_email).to eq("new@gmail.com")
      expect(user.uid).to eq("12345")
      expect(user.provider).to eq("google_oauth2")

      expect(emails.map(&:to)).to eq([[user.email]])
      expect(emails[0].body.encoded).to include("was changed from old@gmail.com to new@gmail.com")
    end

    it "asks Google for the account picker" do
      visit(edit_user_path(user))
      href = find_link("change it")[:href]
      expect(href).to include("intent=change_google_id")
      expect(href).to include("prompt=select_account")
    end

    context "when the member had no Google ID yet" do
      let(:old_google_id) { nil }

      it "offers to link one and links it" do
        visit(edit_user_path(user))
        click_link("link one")
        expect(page).to have_alert(/new@gmail.com/)
        expect(user.reload.google_email).to eq("new@gmail.com")
      end
    end

    context "when Google's address has different case" do
      let(:new_google_id) { "New@Gmail.com" }

      it "stores it normalized" do
        change_google_id
        expect(user.reload.google_email).to eq("new@gmail.com")
      end
    end

    context "when it's the account they already have" do
      let(:new_google_id) { old_google_id }

      it "says so and sends nothing" do
        emails = email_sent_by { change_google_id }
        expect(page).to have_alert("You're already using the Google account old@gmail.com with Gather.")
        expect(emails).to be_empty
      end
    end

    context "when another user has that account" do
      let!(:other_user) { create(:user, google_email: new_google_id) }

      it "refuses and leaves both users alone" do
        emails = email_sent_by { change_google_id }
        expect(page).to have_alert("The Google account new@gmail.com is already used by another Gather " \
                                   "member, so your Google ID was not changed.")
        expect(user.reload.google_email).to eq("old@gmail.com")
        expect(other_user.reload.google_email).to eq("new@gmail.com")
        expect(emails).to be_empty
      end
    end

    context "when the other user is in another cluster" do
      let!(:other_user) do
        with_tenant(create(:cluster)) { create(:user, google_email: new_google_id) }
      end

      it "still refuses, because Google IDs are unique across Gather" do
        change_google_id
        expect(page).to have_alert(/already used by another Gather member/)
        expect(user.reload.google_email).to eq("old@gmail.com")
      end
    end

    context "when Google gives no email" do
      let(:new_google_id) { nil }

      it "refuses" do
        change_google_id
        expect(page).to have_alert("Google did not provide an email address, " \
                                   "so your Google ID was not changed.")
        expect(user.reload.google_email).to eq("old@gmail.com")
      end
    end

    context "when the user's session ended in the meantime" do
      it "sends them to sign in without changing anything" do
        visit(edit_user_path(user))
        link = find_link("change it")
        page.driver.browser.clear_cookies
        link.click
        expect(page).to have_content("your sign-in session expired")
        expect(user.reload.google_email).to eq("old@gmail.com")
      end
    end

    context "when an admin is impersonating the member" do
      let(:admin) { create(:admin) }

      before do
        use_user_subdomain(admin)
        login_as(admin, scope: :user)
      end

      it "hides the link and refuses the change" do
        inject_session(impersonating_id: user.id)
        visit(edit_user_path(user))
        expect(page).to have_field("First Name", with: user.first_name)
        expect(page).not_to have_link("change it")

        # Even posting to Google sign-in directly doesn't link the admin's Google account to the member.
        url = user_google_oauth2_omniauth_authorize_url(host: Settings.url.host, intent: "change_google_id")
        page.driver.browser.process_and_follow_redirects(:post, url)
        expect(page).to have_content("Only the member themself can change their Google ID.")
        expect(user.reload.google_email).to eq("old@gmail.com")
      end
    end
  end

  context "when the member cancels on Google's screen" do
    let(:mock_auth) { :access_denied }

    it "returns to the form without reporting an error" do
      expect(Gather::ErrorReporter.instance).not_to receive(:report)
      change_google_id
      expect(page).to have_alert("Your Google ID was not changed.")
      expect(page).to have_current_path(edit_user_path(user))
      expect(page).to have_signed_in_user(user)
    end
  end

  context "when Google sign-in fails unexpectedly", desktop: true do
    let(:mock_auth) { :invalid_credentials }

    it "reports it and returns to the form" do
      expect(Gather::ErrorReporter.instance).to receive(:report)
      change_google_id
      expect(page).to have_alert("Your Google ID was not changed.")
      expect(page).to have_current_path(edit_user_path(user))
    end
  end

  def change_google_id
    visit(edit_user_path(user))
    click_link("change it")
  end
end
