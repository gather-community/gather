# frozen_string_literal: true

require "rails_helper"

describe "google oauth" do
  let!(:user) { create(:user, google_email: existing_google_id) }
  let(:oauth_google_id) { "foo@gmail.com" }
  let(:existing_google_id) { nil }

  context "with oauth stubbed" do
    before do
      stub_omniauth(google_oauth2: {email: oauth_google_id})
    end

    context "with null email from google" do
      let(:oauth_google_id) { nil }

      it "should show error" do
        visit "/"
        expect_sign_in_with_google_link_and_click
        expect(page).to be_signed_out_root
        expect(page).to have_content("Google did not provide an email address")
      end
    end

    context "with token" do
      let!(:sent_token) { user.send(:set_reset_password_token) }

      context "and token is still valid" do
        context "when user with token has no existing google_email" do
          it "should sign the user in and capture their google ID" do
            visit "/?token=#{sent_token}"
            expect_sign_in_with_google_link_and_click
            expect(page).to be_signed_in_root
            expect(user.reload.google_email).to eq("foo@gmail.com")
          end
        end

        context "when user with token already has the google ID" do
          let(:existing_google_id) { "foo@gmail.com" }

          it "should sign the user in" do
            visit "/?token=#{sent_token}"
            expect_sign_in_with_google_link_and_click
            expect(page).to be_signed_in_root
            expect(user.reload.google_email).to eq("foo@gmail.com")
          end
        end

        context "when user with token has different google_email" do
          let(:existing_google_id) { "bar@gmail.com" }

          it "should fail with error" do
            visit "/?token=#{sent_token}"
            expect_sign_in_with_google_link_and_click
            expect(page).to be_signed_out_root
            expect(page).to have_content("you must sign in with the Google ID bar@gmail.com")
          end
        end

        context "when different user exists with the oauth google ID" do
          let!(:other_user) { create(:user, google_email: "foo@gmail.com", first_name: "Torsten") }

          it "should fail with error" do
            visit "/?token=#{sent_token}"
            expect_sign_in_with_google_link_and_click
            expect(page).to be_signed_out_root
            expect(page).to have_content("your Google ID foo@gmail.com is associated with another user")
          end
        end
      end

      context "and token has expired" do
        it "should show error" do
          Timecop.travel(User.reset_password_within + 1.hour) do
            visit "/?token=#{sent_token}"
            expect_sign_in_with_google_link_and_click
            expect(page).to be_signed_out_root
            expect(page).to have_content("invitation has expired")
            expect(user.reload.google_email).to be_nil
          end
        end
      end

      context "and token is nonsense" do
        it "should show error" do
          visit "/?token=pants"
          expect_sign_in_with_google_link_and_click
          expect(page).to be_signed_out_root
          expect(page).to have_content("foo@gmail.com was not found in the system")
        end
      end
    end

    context "with matching email" do
      let(:existing_google_id) { oauth_google_id }

      it "should sign the user in and remember after cookie cleared" do
        visit "/"
        expect_sign_in_with_google_link_and_click
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
        expect_sign_in_with_google_link_and_click
        expect(page).to be_signed_out_root
        expect(page).to have_content("foo@gmail.com was not found in the system")
      end
    end

    context "with unconfirmed user" do
      let!(:user) { create(:user, :unconfirmed, email: email, google_email: "foo@gmail.com") }

      context "when google ID different from email" do
        let(:email) { "foo@isp.net" }

        scenario "denies login without invite" do
          visit("/")
          expect_sign_in_with_google_link_and_click
          expect(page).to be_signed_out_root
          expect(page).to have_content("you must use an invititation when first signing in")
        end
      end

      context "when google ID same as email" do
        let(:email) { "foo@gmail.com" }

        scenario "signs in and confirms" do
          visit("/")
          expect_sign_in_with_google_link_and_click
          expect(page).to be_signed_in_root
          expect(user.reload).to be_confirmed
        end
      end
    end
  end

  context "with oauth failure" do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = failure_type
    end

    context "when user cancels on Google" do
      let(:failure_type) { :access_denied }

      it "should show cancelled message without reporting" do
        expect(Gather::ErrorReporter.instance).not_to receive(:report)
        visit "/"
        expect_sign_in_with_google_link_and_click
        expect(page).to be_signed_out_root
        expect(page).to have_content("Could not sign you in from Google because the sign-in was cancelled.")
      end
    end

    context "with csrf failure" do
      let(:failure_type) { :csrf_detected }

      context "when not signed in" do
        it "should ask user to try again without reporting" do
          expect(Gather::ErrorReporter.instance).not_to receive(:report)
          visit "/"
          expect_sign_in_with_google_link_and_click
          expect(page).to be_signed_out_root
          expect(page).to have_content("your sign-in session expired. Please try again.")
        end
      end

      context "when already signed in" do
        let(:existing_google_id) { "foo@gmail.com" }

        it "should redirect to home without error" do
          expect(Gather::ErrorReporter.instance).not_to receive(:report)
          login_as(user, scope: :user)
          visit "/people/users/auth/google_oauth2/callback"
          expect(page).to have_signed_in_user(user)
          expect(page).not_to have_content("Could not sign you in")
        end
      end
    end

    context "with other failure", desktop: true do
      let(:failure_type) { :invalid_credentials }

      it "should report without request env" do
        expect(Gather::ErrorReporter.instance).to receive(:report) do |error, **kwargs|
          expect(error.message).to eq("OAuth failure")
          expect(kwargs).not_to have_key(:env)
          expect(kwargs[:data][:error_type]).to eq(:invalid_credentials)
        end
        visit "/"
        expect_sign_in_with_google_link_and_click
        expect(page).to be_signed_out_root
        expect(page).to have_content("Could not sign you in from Google because of an unspecified error.")
      end
    end
  end

  context "without oauth stubbed", desktop: true do
    context "with invalid query params on callback" do
      it "should treat as expired session without reporting" do
        expect(Gather::ErrorReporter.instance).not_to receive(:report)
        visit "/people/users/auth/google_oauth2/callback" # No params
        expect(page).to be_signed_out_root
        expect(page).to have_content("your sign-in session expired. Please try again.")
      end
    end
  end
end
