# frozen_string_literal: true

FactoryBot.define do
  factory :meal_type, class: "Meals::Type" do
    name { "Adult Veg" }
    discounted { false }
    portion_type { "Veg" }
    community_id { Defaults.community.id }
  end
end
