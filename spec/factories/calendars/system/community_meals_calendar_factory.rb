# frozen_string_literal: true

FactoryBot.define do
  factory :community_meals_calendar, class: "Calendars::System::CommunityMealsCalendar" do
    sequence(:name) { |n| "Cmty Meals #{n}" }
    community { Defaults.community }
    sequence(:color) { |n| "##{n.to_s.ljust(6, '0')}" }
  end
end
