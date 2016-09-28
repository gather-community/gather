require "rails_helper"

feature "calendar export" do
  let!(:user) { create(:user, calendar_token: "xyz") }

  scenario "your meals" do
    visit("/calendars/meals/xyz.ics")
    expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
      "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals You're Attending END:VCALENDAR")
  end

  scenario "all meals" do
    visit("/calendars/all-meals/xyz.ics")
    expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
      "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:All Meals END:VCALENDAR")
  end

  scenario "community meals" do
    visit("/calendars/community-meals/xyz.ics")
    expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
      "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals END:VCALENDAR")
  end

  scenario "community meals" do
    visit("/calendars/shifts/xyz.ics")
    expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
      "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Your Meal Work Shifts END:VCALENDAR")
  end

  scenario "reservations" do
    visit("/calendars/reservations/xyz.ics")
    expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
      "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Reservations END:VCALENDAR")
  end

  scenario "bad calendar type" do
    visit("/calendars/pants/xyz.ics")
    expect(page).to have_content("Invalid calendar type")
  end

  scenario "bad token" do
    visit("/calendars/meals/xyzw.ics")
    expect(page).to have_content("Please log in")
  end
end
