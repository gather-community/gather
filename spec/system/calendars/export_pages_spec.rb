# frozen_string_literal: true

require "rails_helper"

describe "calendar export pages" do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let!(:user) { create(:user, calendar_token: user_token) }

  before do
    Defaults.community.update!(calendar_token: cmty_token)
    login_as(user, scope: :user)
    use_user_subdomain(user)
  end

  scenario "index" do
    visit("/calendars/exports")
    within(".personalized-links") { click_link("All Meals") }
    expect(page).to have_content("BEGIN:VCALENDAR")
  end

  scenario "reset_token" do
    visit("/calendars/exports")
    old_token = token_from_url
    click_link("click here to reset your secret token")
    expect(page).to have_content("Token reset successfully")
    expect(token_from_url).not_to eq(old_token)
    within(".personalized-links") { click_link("All Meals") }
    expect(page).to have_content("BEGIN:VCALENDAR")
  end

  def token_from_url
    within(".personalized-links") do
      find("a", text: "All Meals")[:href].match(%r{/([A-Za-z0-9_\-]{20})\.ics})[1]
    end
  end
end
