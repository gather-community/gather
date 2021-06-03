# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::CommunityMealsCalendar do
  let(:community) { Defaults.community }
  let(:communityB) { create(:community) }
  let(:user) { create(:user, community: community) }
  let!(:meal1) do
    create(:meal, head_cook: user, served_at: Time.current + 1.day)
  end
  let!(:meal2) do
    create(:meal, :with_menu, title: "Meal2", served_at: Time.current + 2.days)
  end
  let!(:meal3) do
    create(:meal, :with_menu, title: "Other Cmty Meal", community: communityB,
                              served_at: Time.current + 3.days,
                              communities: [meal1.community, communityB])
  end
  let!(:cancelled_meal) do
    create(:meal, :cancelled, served_at: meal1.served_at)
  end
  let!(:signup1) do
    create(:meal_signup, meal: meal1, household: user.household, comments: "Foo\nBar", diner_counts: [2])
  end
  let!(:signup2) do
    create(:meal_signup, meal: cancelled_meal, household: user.household, diner_counts: [2])
  end
  let(:calendar) { create(:community_meals_calendar) }

  context "community meals" do
    it "returns correct event attribs" do
      attribs = [{
        name: "[No Menu]",
        starts_at: meal1.served_at,
        ends_at: meal1.served_at + 1.hour,
        meal_id: meal1.id,
        creator_id: meal1.creator_id
      }, {
        name: "Meal2",
        starts_at: meal2.served_at,
        ends_at: meal2.served_at + 1.hour,
        meal_id: meal2.id,
        creator_id: meal2.creator_id
      }]
      events = calendar.events_between((Time.current - 2.days)..(Time.current + 4.days))
      expect_events(events, *attribs)
    end

    it "returns events with signup indication" do
      attribs = [{
        name: "[No Menu] ✓"
      }, {
        name: "Meal2"
      }]
      events = calendar.events_between((Time.current - 2.days)..(Time.current + 4.days), user: user)
      expect_events(events, *attribs)
    end

    it "returns correct events inside tighter range" do
      events = calendar.events_between((meal1.served_at - 5.minutes)..(meal1.served_at + 1.hour))
      expect_events(events, name: "[No Menu]")
      events = calendar.events_between((meal2.served_at + 15.minutes)..(meal2.served_at + 30.minutes))
      expect_events(events, name: "Meal2")
    end
  end

  def expect_events(events, *attribs)
    expect(events.size).to eq(attribs.size)
    events.each_with_index do |event, i|
      expect_event(event, attribs[i])
    end
  end

  def expect_event(event, attribs)
    attribs = {kind: nil, note: nil, sponsor_id: nil, calendar_id: calendar.id}.merge(attribs)
    attribs.each { |k, v| expect(event[k]).to eq(attribs[k]), "#{k} should eq #{v}" }
  end
end
