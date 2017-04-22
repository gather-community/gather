require "rails_helper"

feature "calendar export" do
  let!(:user) { create(:user, calendar_token: "xyz") }

  shared_examples_for "your meals" do
    scenario "your meals" do
      visit("/calendars/meals/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals You're Attending")
    end
  end

  context "with user subdomain" do
    around { |ex| with_user_home_subdomain(user) { ex.run } }

    it_behaves_like "your meals"

    scenario "all meals" do
      visit("/calendars/all-meals/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:All Meals")
    end

    scenario "community meals" do
      visit("/calendars/community-meals/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals")
    end

    scenario "jobs" do
      visit("/calendars/shifts/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Your Meal Jobs")
    end

    scenario "reservations" do
      visit("/calendars/reservations/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Reservations")
    end

    scenario "your reservations" do
      visit("/calendars/your-reservations/xyz.ics")
      expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
        "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Your Reservations")
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

  context "with apex subdomain" do
    it_behaves_like "your meals"
  end
end
