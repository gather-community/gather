# frozen_string_literal: true

FactoryBot.define do
  factory :meal_type, class: "Meals::Type" do
    name { "Adult Veg" }
    subtype { "Veg" }
    community { Defaults.community }
  end
end
