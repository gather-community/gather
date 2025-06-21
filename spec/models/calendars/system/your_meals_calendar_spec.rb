# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
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
    expect_events(events, *[])
  end
end
