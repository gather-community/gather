FactoryGirl.define do
  factory :meal_cost do
    ingredient_cost 10.00
    pantry_cost 2.00
    payment_method "check"
  end
end