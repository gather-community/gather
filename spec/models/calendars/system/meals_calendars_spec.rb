# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::MealsCalendar do
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
  let!(:meal4) do
    create(:meal, :with_menu, title: "Other Cmty Meal 2", community: communityB,
                              served_at: Time.current + 4.days,
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
  let!(:signup3) do
    create(:meal_signup, meal: meal3, household: user.household, comments: "Foo\nBar", diner_counts: [2])
  end

  describe Calendars::System::CommunityMealsCalendar do
    let(:calendar) { create(:community_meals_calendar) }

    it "returns correct event attribs" do
      attribs = [{
        name: "[No Menu] ✓",
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
      events = calendar.events_between((Time.current - 2.days)..(Time.current + 4.days), user: user)
      expect_events(events, *attribs)
    end

    it "returns correct events inside tighter range" do
      range = (meal1.served_at - 5.minutes)..(meal1.served_at + 1.hour)
      events = calendar.events_between(range, user: user)
      expect_events(events, name: "[No Menu] ✓")
      range = (meal2.served_at + 15.minutes)..(meal2.served_at + 30.minutes)
      events = calendar.events_between(range, user: user)
      expect_events(events, name: "Meal2")
    end
  end

  describe Calendars::System::OtherCommunitiesMealsCalendar do
    let(:calendar) { create(:other_communities_meals_calendar) }

    it "includes only meals from other cmtys" do
      attribs = [{name: "Other Cmty Meal ✓"}, {name: "Other Cmty Meal 2"}]
      events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), user: user)
      expect_events(events, *attribs)
    end
  end

  describe Calendars::System::YourMealsCalendar do
    let(:calendar) { create(:your_meals_calendar) }

    it "includes only meals signed up for" do
      attribs = [{name: "[No Menu] ✓"}, {name: "Other Cmty Meal ✓"}]
      events = calendar.events_between((Time.current - 2.days)..(Time.current + 5.days), user: user)
      expect_events(events, *attribs)
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
