FactoryGirl.define do
  factory :meals_formula, class: "Meals::Formula" do
    community { default_community }
    effective_on "2015-01-01"
    senior_meat 0.75
    senior_veg 0.6
    adult_meat 1.0
    adult_veg 0.9
    big_kid_meat 0.75
    big_kid_veg 0.6
    little_kid_meat 0
    little_kid_veg 0
    pantry_fee 0.10
    meal_calc_type "share"
    pantry_calc_type "percent"
  end
end
