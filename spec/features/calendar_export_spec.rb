require "rails_helper"

feature "calendar export" do
  let!(:user) { create(:user, calendar_token: "xyz") }

  scenario "good token" do
    visit("/calendars/meals/xyz.ics")
    expect(page).to have_content("Please log in")
  end

  scenario "bad token" do
    visit("/calendars/meals/xyzw.ics")
    expect(page).to have_content("Please log in")
  end
end
