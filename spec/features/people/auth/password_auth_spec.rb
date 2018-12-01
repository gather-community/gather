# frozen_string_literal: true

require "rails_helper"

feature "password auth" do
  let!(:user) { create(:user) }

  scenario "login after failure" do
    visit(root_path)
    click_on("Sign in with Password")
    fill_in("Email Address", with: user.email)
    fill_in("Password", with: "#{DEFAULT_PASSWORD}x")
    click_button("Sign In")
    expect(page).to have_alert("Invalid email or password.")
    fill_in("Password", with: DEFAULT_PASSWORD)
    click_button("Sign In")
    expect(page).to have_signed_in_user(user)
  end

  scenario "login without remember me" do
    visit(root_path)
    click_on("Sign in with Password")
    fill_in("Email Address", with: user.email)
    fill_in("Password", with: DEFAULT_PASSWORD)
    uncheck("Keep me logged in after I close my browser")
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
    fill_in("Password", with: DEFAULT_PASSWORD)
    check("Keep me logged in after I close my browser")
    click_button("Sign In")
    expect(page).to have_signed_in_user(user)
    clear_session_cookie
    visit(meals_path)
    expect(page).to have_signed_in_user(user)
  end
end
