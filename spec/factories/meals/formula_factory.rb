FactoryBot.define do
  factory :meal_formula, class: "Meals::Formula" do
    sequence(:name) { |n| "Formula #{n}" }
    community { default_community }
    senior_meat 0.75
    senior_veg 0.6
    adult_meat 1.0
    adult_veg 0.9
    teen_meat 1.0
    teen_veg 0.9
    big_kid_meat 0.75
    big_kid_veg 0.6
    little_kid_meat 0
    little_kid_veg 0
    pantry_fee 0.10
    meal_calc_type "share"
    pantry_calc_type "percent"
  end
end
