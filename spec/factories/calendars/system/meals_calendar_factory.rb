# frozen_string_literal: true

FactoryBot.define do
  factory :meals_calendar, class: "Calendars::System::MealsCalendar" do
    community { Defaults.community }
    sequence(:color) { |n| "##{n.to_s.ljust(6, '0')}" }

    factory :community_meals_calendar, class: "Calendars::System::CommunityMealsCalendar" do
      sequence(:name) { |n| "Cmty Meals #{n}" }
    end

    factory :other_communities_meals_calendar, class: "Calendars::System::OtherCommunitiesMealsCalendar" do
      sequence(:name) { |n| "Oth Cmtys Meals #{n}" }
    end

    factory :your_meals_calendar, class: "Calendars::System::YourMealsCalendar" do
      sequence(:name) { |n| "Your Meals #{n}" }
    end
  end
end
