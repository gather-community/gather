# frozen_string_literal: true

FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "Community #{n}" }
    sequence(:abbrv) { |n| "C#{n % 10}" }
    sequence(:slug) { |n| "community#{n}" }
  end
end
