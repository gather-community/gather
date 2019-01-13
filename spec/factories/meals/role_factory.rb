# frozen_string_literal: true

FactoryBot.define do
  factory :meal_role, class: "Meals::Role" do
    sequence(:title) { |n| "#{Faker::Job.title} #{n}" }
    community { default_community }
    time_type { "date_only" }
    description { Faker::Lorem.paragraph }
  end
end
