# frozen_string_literal: true

require "rails_helper"

feature "email confirmation", js: true do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  context "with google ID but no confirmed email" do
    let!(:user) { create(:user, :unconfirmed, email: email, google_email: "foo@gmail.com") }

    around do |example|
      stub_omniauth(google_oauth2: {email: "foo@gmail.com"}) { example.run }
    end

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
