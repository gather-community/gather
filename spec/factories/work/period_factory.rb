# frozen_string_literal: true

FactoryBot.define do
  factory :work_period, class: "Work::Period" do
    sequence(:name) { |n| "#{Faker::Lorem.word.capitalize} #{n}" }
    starts_on { Date.new(2018, 1, 1) }
    ends_on { starts_on + 30.days }
    community { Defaults.community }
    pick_type { "free_for_all" }

    trait :with_shares do
      after(:create) do |period|
        User.in_community(period.community).each { |u| period.shares.create!(user: u, portion: 1) }
      end
    end
  end
end
