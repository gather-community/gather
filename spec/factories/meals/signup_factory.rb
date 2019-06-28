# frozen_string_literal: true

FactoryBot.define do
  factory :meal_signup, class: "Meals::Signup" do
    transient do
      # Type-agnostic way of requesting a specific number of diners be included in the signup
      diner_count { nil }
    end

    household
    meal

    after(:build) do |signup, evaluator|
      signup.adult_meat = evaluator.diner_count if evaluator.diner_count
    end

    trait :with_nums do
      adult_meat { 2 }
      little_kid_veg { 1 }
    end
  end
end
