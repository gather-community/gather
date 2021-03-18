# frozen_string_literal: true

FactoryBot.define do
  factory :calendar, class: "Calendars::Calendar" do
    sequence(:name) { |n| "Calendar #{n}" }
    sequence(:abbrv) { |n| "Res#{n}" }
    community { Defaults.community }

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end

    trait :with_shared_guidelines do
      guidelines { "Guideline 1" }

      after(:build) do |calendar|
        calendar.shared_guidelines.build(community: calendar.community, name: "Foo", body: "Guideline 2")
        calendar.shared_guidelines.build(community: calendar.community, name: "Bar", body: "Guideline 3")
      end
    end
  end
end
