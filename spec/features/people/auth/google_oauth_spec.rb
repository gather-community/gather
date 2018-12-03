# frozen_string_literal: true

require "rails_helper"

feature "google oauth" do
  let!(:user) { create(:user, google_email: existing_google_id) }
  let(:oauth_google_id) { "foo@gmail.com" }
  let(:existing_google_id) { nil }

  context "with oauth stubbed" do
    around do |example|
      stub_omniauth(google_oauth2: {email: oauth_google_id}) { example.run }
    end

    context "with token" do
      let!(:sent_token) { user.send(:set_reset_password_token) }

      context "and token is still valid" do
        context "with no existing google_email" do
          it "should sign the user in and capture their google ID" do
            visit "/?token=#{sent_token}"
            expect_valid_sign_in_link_and_click
            expect(page).to be_signed_in_root
            expect(user.reload.google_email).to eq("foo@gmail.com")
          end
        end

        context "with different google_email" do
          let(:existing_google_id) { "bar@gmail.com" }

          it "should fail with error" do
            visit "/?token=#{sent_token}"
            expect_valid_sign_in_link_and_click
            expect(page).to be_signed_out_root
            expect(page).to have_content("you must sign in with the Google ID bar@gmail.com")
          end
        end

        context "and different user exists with the oauth google ID" do
          let!(:other_user) { create(:user, google_email: "foo@gmail.com", first_name: "Torsten") }

          it "should sign in the other user" do
            visit "/?token=#{sent_token}"
            expect_valid_sign_in_link_and_click
            expect(page).to be_signed_in_root
            expect(page).to show_signed_in_user_name("Torsten")
          end
        end
      end

      context "and token has expired" do
        it "should show error" do
          Timecop.travel(User.reset_password_within + 1.hour) do
            visit "/?token=#{sent_token}"
            expect_valid_sign_in_link_and_click
            expect(page).to be_signed_out_root
            expect(page).to have_content("invitation has expired")
            expect(user.reload.google_email).to be_nil
          end
        end
      end

      context "and token is nonsense" do
        it "should show error" do
          visit "/?token=pants"
          expect_valid_sign_in_link_and_click
          expect(page).to be_signed_out_root
          expect(page).to have_content("foo@gmail.com was not found in the system")
        end
      end
    end

    context "with matching email" do
      let(:existing_google_id) { oauth_google_id }

      it "should sign the user in and remember after cookie cleared" do
        visit "/"
        expect_valid_sign_in_link_and_click
        expect(page).to have_signed_in_user(user)
        clear_session_cookie
        visit(meals_path)
        expect(page).to have_signed_in_user(user)
      end
    end

    context "with non-matching email" do
      let(:existing_google_id) { "junk@gmail.com" }

      it "should show error" do
        visit "/"
        expect_valid_sign_in_link_and_click
        expect(page).to be_signed_out_root
        expect(page).to have_content("foo@gmail.com was not found in the system")
      end
    end
  end

  context "without oauth stubbed" do
    context "with invalid query params on callback" do
      it "should show error" do
        email_sent = email_sent_by do
          visit "/people/users/auth/google_oauth2/callback" # No params
          expect(page).to be_signed_out_root
          expect(page).to have_content("Could not sign you in from Google because of an unspecified error.")
        end
        expect(email_sent.size).to eq(1)
      end
    end
  end
end
