# frozen_string_literal: true

require "rails_helper"

feature "password auth" do
  context "with confirmed user" do
    let!(:user) { create(:user) }

    scenario "login after failure" do
      visit(root_path)
      click_on("Sign in with Password")
      fill_in("Email Address", with: user.email)
      fill_in("Password", with: "#{FactoryBot::DEFAULT_PASSWORD}x")
      click_button("Sign In")
      expect(page).not_to have_signed_in_user(user)
      expect(page).to have_alert("Invalid email or password.")
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      click_button("Sign In")
      expect(page).to have_signed_in_user(user)
    end

    scenario "login without remember me" do
      visit(root_path)
      click_on("Sign in with Password")
      fill_in("Email Address", with: user.email)
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      uncheck("Stay signed in after you close your browser")
      click_button("Sign In")
      expect(page).to have_signed_in_user(user)
      clear_session_cookie
      visit(meals_path)
      expect(page).to have_content("Please sign in to view that page")
    end

    scenario "login with remember me" do
      visit(root_path)
      click_on("Sign in with Password")
      fill_in("Email Address", with: user.email)
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      check("Stay signed in after you close your browser")
      click_button("Sign In")
      expect(page).to have_signed_in_user(user)
      clear_session_cookie
      visit(meals_path)
      expect(page).to have_signed_in_user(user)
    end

    scenario "forgot password", js: true do
      visit(root_path)
      click_on("Sign in with Password")
      click_on("I don't know my password")
      fill_in("Email Address", with: "#{user.email}x")
      click_on("Send Reset Instructions")
      expect(page).to have_content("Email not found")
      submit_email_and_visit_new_password_entry_page

      click_on("Set Password")
      expect_validation_message(/Can't be blank/)

      fill_in("New Password", with: "48hafeirafar42", match: :prefer_exact)
      fill_in("Re-type New Password", with: "x")
      click_on("Set Password")

      expect_validation_message("Didn't match password")
      fill_in("New Password", with: "48hafeirafar42", match: :prefer_exact)
      expect_validation_message("Good")
      fill_in("Re-type New Password", with: "48hafeirafar42")
      click_on("Set Password")

      expect(page).to have_alert("Your password has been changed successfully. You are now signed in.")
    end
  end

  context "with unconfirmed user" do
    let!(:user) { create(:user, :unconfirmed) }

    scenario "denies login" do
      visit(root_path)
      click_on("Sign in with Password")
      fill_in("Email Address", with: user.email)
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      click_button("Sign In")
      expect(page).not_to have_signed_in_user(user)
      expect(page).to have_alert("You must use an invititation when first signing in.")
    end
  end

  context "with user pending reconfirmation" do
    let!(:user) { create(:user, :pending_reconfirmation) }

    scenario "allows login but doesn't update email" do
      visit(root_path)
      click_on("Sign in with Password")
      fill_in("Email Address", with: user.email)
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      click_button("Sign In")
      expect(page).to have_signed_in_user(user)
      expect(user.reload.unconfirmed_email).not_to be_nil
    end

    scenario "allows password reset but doesn't update email" do
      orig_email = user.email

      visit(root_path)
      click_on("Sign in with Password")
      click_on("I don't know my password")
      submit_email_and_visit_new_password_entry_page

      fill_in("New Password", with: "48hafeirafar42", match: :prefer_exact)
      fill_in("Re-type New Password", with: "48hafeirafar42", match: :prefer_exact)
      click_on("Set Password")

      expect(page).to have_alert("Your password has been changed successfully. You are now signed in.")
      expect(page).to have_signed_in_user(user)
      expect(user.reload.email).to eq(orig_email)
      expect(user.unconfirmed_email).not_to be_nil
    end
  end

  def submit_email_and_visit_new_password_entry_page
    fill_in("Email Address", with: user.email)
    email_sent = email_sent_by do
      click_on("Send Reset Instructions")
      expect(page).to have_alert("You will receive an email with "\
        "instructions on how to reset your password")
    end
    body = email_sent[0].body.encoded
    match_and_visit_url(body, %r{https?://.+/people/users/password/edit\?reset_password_token=.+$})
  end
end
