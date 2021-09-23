# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::YourMealsCalendar do
  include_context "system calendars"
  include_context "meals system calendars"

  let(:calendar) { create(:your_meals_calendar) }

  it "includes only meals signed up for" do
    attribs = [{name: "[No Menu] ✓"}, {name: "Other Cmty Meal ✓"}]
    events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), user: user)
    expect_events(events, *attribs)
  end
end
