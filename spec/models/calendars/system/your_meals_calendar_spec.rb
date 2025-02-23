# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::YourMealsCalendar do
  include_context "system calendars"
  include_context "meals system calendars"

  let(:calendar) { create(:your_meals_calendar) }

  it "includes only meals signed up for" do
    attribs = [
      {name: "[No Menu] ✓", uid: "your_meals_#{meal1.id}"},
      {name: "Other Cmty Meal ✓", uid: "your_meals_#{meal3.id}"}
    ]
    events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), actor: actor)
    expect_events(events, *attribs)
  end

  it "returns nothing if no actor given" do
    events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), actor: nil)
    expect_events(events)
  end
end
