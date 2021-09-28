# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::OtherCommunitiesMealsCalendar do
  include_context "system calendars"
  include_context "meals system calendars"

  let(:calendar) { create(:other_communities_meals_calendar) }

  it "includes only meals from other cmtys" do
    attribs = [{name: "Other Cmty Meal ✓"}, {name: "Other Cmty Meal 2"}]
    events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), actor: actor)
    expect_events(events, *attribs)
  end
end
