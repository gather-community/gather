# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_group, class: "Calendars::Group" do
    sequence(:name) { |n| "Calendar Group #{n}" }
    community { Defaults.community }

    trait :with_calendars do
      after(:build) do |group|
        2.times { group.calendars.build(build(:calendar).attributes) }
      end
    end
  end
end
