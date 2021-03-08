# frozen_string_literal: true

FactoryBot.define do
  factory :meal_cost, class: "Meals::Cost" do
    meal
    association :reimbursee, factory: :user
    ingredient_cost { 10.00 }
    pantry_cost { 2.00 }
    payment_method { "check" }

    trait :with_parts do
      after(:build) do |cost|
        formula = cost.meal.formula
        cost.parts.build(type: formula.types.first, value: 3.56)
      end
    end
  end
end
