# frozen_string_literal: true

FactoryBot.define do
  factory :meal_cost, class: "Meals::Cost" do
    meal
    ingredient_cost { 10.00 }
    pantry_cost { 2.00 }
    payment_method { "check" }

    after(:build) do |cost|
      formula = cost.meal.formula
      cost.parts.build(type: formula.types.first, value: 3.56)
    end
  end
end
