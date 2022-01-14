# frozen_string_literal: true

shared_context "meals system calendars" do
  let(:community) { Defaults.community }
  let(:communityB) { create(:community) }
  let(:actor) { create(:user, community: community) }
  let(:full_range) { (Time.current - 2.days)..(Time.current + 4.days) }
  let(:dining_room) { create(:calendar, name: "Dining Room") }
  let(:kitchen) { create(:calendar, name: "Kitchen") }
  let!(:meal1) do
    create(:meal, head_cook: actor, calendars: [dining_room, kitchen], served_at: Time.current + 1.day)
  end
  let!(:meal2) do
    create(:meal, :with_menu, title: "Meal2", calendars: [kitchen], served_at: Time.current + 2.days)
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
    create(:meal_signup, meal: meal1, household: actor.household, comments: "Foo\nBar", diner_counts: [2])
  end
  let!(:signup2) do
    create(:meal_signup, meal: cancelled_meal, household: actor.household, diner_counts: [2])
  end
  let!(:signup3) do
    create(:meal_signup, meal: meal3, household: actor.household, comments: "Foo\nBar", diner_counts: [2])
  end
end
