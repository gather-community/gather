# frozen_string_literal: true

FactoryBot.define do
  factory :meal_formula_part, class: "Meals::FormulaPart" do
    association(:formula, factory: :meal_formula)
    association(:type, factory: :meal_type)
    share { 0.75 }
  end
end
