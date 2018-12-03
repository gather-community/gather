# frozen_string_literal: true

require "rails_helper"

feature "sign in invitations", js: true do
  let(:actor) { create(:admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  describe "google oauth happy path" do
    let!(:invitee) { create(:user, first_name: "Bob", last_name: "Flob", google_email: nil) }
    let!(:decoy) { create(:user) }

    around do |example|
      stub_omniauth(google_oauth2: {email: "bob1234flob@gmail.com"}) { example.run }
    end

    it do
      full_sign_in_as(actor)
      visit(user_path(invitee))
      accept_confirm { click_on("Invite") }
      expect_success(/Invitation sent./)
      full_sign_out

      expect_worker_to_send_emails(count: 1)

      # Get the link from the email and visit it.
      url_regex = %r{https?://.+/?token=.+$}
      email = ActionMailer::Base.deliveries.last.body.encoded
      expect(email).to match(/Bob Flob/)
      match_and_visit_url(email, url_regex)

      # Sign in with Google.
      # If the user's google email has been updated, we know the token process worked as expected.
      click_link("Sign in with Google")
      expect(page).to have_signed_in_user(invitee)
      expect(invitee.reload.google_email).to eq("bob1234flob@gmail.com")
    end
  end

  describe "password happy path" do
    let!(:invitee) { create(:user, first_name: "Bob", last_name: "Flob") }
    let!(:decoy) { create(:user) }

    it do
      full_sign_in_as(actor)
      visit(user_path(invitee))
      accept_confirm { click_on("Invite") }
      expect_success(/Invitation sent./)
      full_sign_out

      expect_worker_to_send_emails(count: 1)

      # Get the link from the email and visit it.
      url_regex = %r{https?://.+/?token=.+$}
      email = ActionMailer::Base.deliveries.last.body.encoded
      expect(email).to match(/Bob Flob/)
      match_and_visit_url(email, url_regex)

      click_link("Sign in with Password")
      click_link("Don't know your password")
      expect(page).to have_title("Enter a New Password")
      fill_in("New Password", with: "48hafeirafar42", match: :prefer_exact)
      fill_in("Re-type New Password", with: "48hafeirafar42")
      click_on("Reset Password")
      expect(page).to have_alert("Your password has been changed successfully. You are now signed in.")
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

      expect_worker_to_send_emails(count: 2)
      expect(ActionMailer::Base.deliveries[-2..-1].map(&:to))
        .to contain_exactly([invitee2.email], [invitee3.email])
    end
  end

  def expect_worker_to_send_emails(count:)
    expect { Delayed::Worker.new.work_off }.to change { ActionMailer::Base.deliveries.size }.by(count)
  end
end
