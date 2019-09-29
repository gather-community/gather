# frozen_string_literal: true

FactoryBot.define do
  factory :meal_type, class: "Meals::Type" do
    sequence(:name) { |n| "Type #{n}" }
    category { %w[Meat Veg].sample }
    community { Defaults.community }
  end
end
