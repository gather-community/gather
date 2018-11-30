# frozen_string_literal: true

require "rails_helper"

feature "sign in invitations", js: true do
  let(:actor) { create(:admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  describe "bulk send" do
    describe "google oauth happy path" do
      let!(:invitee1) { create(:user, sign_in_count: 10) }
      let!(:invitee2) { create(:user, first_name: "Bob", last_name: "Flob", google_email: nil) }
      let!(:invitee3) { create(:user, first_name: "Squib", last_name: "Flib") }
      let!(:decoy) { create(:user, :inactive) }

      around do |example|
        stub_omniauth(google_oauth2: {email: "bob1234flob@gmail.com"}) { example.run }
      end

      scenario do
        full_sign_in_as(actor)

        # Send the invitations.
        visit(users_path)
        find(".top-buttons .btn-primary.dropdown-toggle").click
        click_on("Invite To Sign In")
        within(find(:xpath, "//label[text()[contains(., '#{invitee2.name}')]]")) do
          expect(page).to have_css("i.fa-question-circle")
        end
        within(find(:xpath, "//label[text()[contains(., '#{invitee1.name}')]]")) do
          expect(page).not_to have_css("i.fa-question-circle")
        end
        click_on("Select All No-Sign-Ins")
        click_button("Send Invitations")
        expect_success(/Invitations sent./)
        full_sign_out
        Delayed::Worker.new.work_off

        # Get the link from the email and visit it.
        url_regex = %r{https?://.+/?token=.+$}
        email = ActionMailer::Base.deliveries.detect { |d| d.body.encoded.include?("Flob") }.body.encoded
        expect(email).to match(/Bob Flob/)
        expect(email).to match(url_regex)
        visit(email.match(url_regex)[0].strip)

        # Sign in with Google.
        # If the user's google email has been updated, we know the token process worked as expected.
        click_link("Sign in with Google")
        expect(page).to have_content("Bob Flob")
        expect(invitee2.reload.google_email).to eq("bob1234flob@gmail.com")
      end
    end
  end
end
