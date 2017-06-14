FactoryGirl.define do
  factory :meals_formula, class: "Meals::Formula" do
    community { default_community }
    effective_on "2015-01-01"
    adult_meat 1.0
    adult_veg 0.9
    big_kid_meat 0.75
    big_kid_veg 0.6
    pantry_fee 0.10
    meal_calc_type "share"
    pantry_calc_type "percent"
  end
end
