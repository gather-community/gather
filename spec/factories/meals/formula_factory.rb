FactoryGirl.define do
  factory :meals_formula, class: "Meals::Formula" do
    community { default_community }
    effective_on "2015-01-01"
    adult_meat 2.00
    adult_veg 1.50
    pantry_fee 0.10
    meal_calc_type "fixed"
    pantry_calc_type "fixed"
  end
end
