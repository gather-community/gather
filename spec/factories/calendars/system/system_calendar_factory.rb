# frozen_string_literal: true

FactoryBot.define do
  factory :system_calendar, class: "Calendars::System::SystemCalendar" do
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

    factory :birthdays_calendar, class: "Calendars::System::BirthdaysCalendar" do
      sequence(:name) { |n| "Birthdays #{n}" }
    end

    factory :join_dates_calendar, class: "Calendars::System::JoinDatesCalendar" do
      sequence(:name) { |n| "Join Dates #{n}" }
    end

    factory :your_jobs_calendar, class: "Calendars::System::YourJobsCalendar" do
      sequence(:name) { |n| "Your Jobs #{n}" }
    end
  end
end
