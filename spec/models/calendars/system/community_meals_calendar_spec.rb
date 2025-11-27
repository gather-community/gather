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

describe Calendars::System::CommunityMealsCalendar do
  include_context "system calendars"
  include_context "meals system calendars"

  let(:calendar) { create(:community_meals_calendar) }

  context "with actor" do
    it "returns correct event attribs" do
      attribs = [{
        name: "[No Menu] ✓",
        starts_at: meal1.served_at,
        ends_at: meal1.served_at + 1.hour,
        meal_id: meal1.id,
        creator_id: nil,
        linkable: meal1,
        location: "#{community.abbrv} Dining Room",
        uid: "Meal_#{meal1.id}",
        note: "By #{meal1.head_cook_name}\n2 diners from your household\nSignup comments:\nFoo\nBar"
      }, {
        name: "Meal2",
        starts_at: meal2.served_at,
        ends_at: meal2.served_at + 1.hour,
        meal_id: meal2.id,
        creator_id: nil,
        linkable: meal2,
        location: "#{community.abbrv} Kitchen",
        uid: "Meal_#{meal2.id}",
        note: "By #{meal2.head_cook_name}"
      }]
      events = calendar.events_between(full_range, actor: actor)
      expect_events(events, *attribs)
    end

    it "returns correct events inside tighter range" do
      range = (meal1.served_at - 5.minutes)..(meal1.served_at + 1.hour)
      events = calendar.events_between(range, actor: actor)
      expect_events(events, name: "[No Menu] ✓")
      range = (meal2.served_at + 15.minutes)..(meal2.served_at + 30.minutes)
      events = calendar.events_between(range, actor: actor)
      expect_events(events, name: "Meal2")
    end

    it "respects policy scope" do
      null_scope = double(resolve: Meals::Meal.none)
      expect(Meals::MealPolicy::Scope).to receive(:new).and_return(null_scope)
      expect(calendar.events_between(full_range, actor: actor)).to be_empty
    end
  end

  context "without actor" do
    it "returns attribs without personalization" do
      attribs = [{
        name: "[No Menu]",
        note: "By #{meal1.head_cook_name}"
      }, {
        name: "Meal2",
        note: "By #{meal2.head_cook_name}"
      }]
      events = calendar.events_between(full_range, actor: nil)
      expect_events(events, *attribs)
    end
  end
end
