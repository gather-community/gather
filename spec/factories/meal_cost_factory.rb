FactoryGirl.define do
  factory :meal_cost, class: "Meals::Cost" do
    ingredient_cost 10.00
    pantry_cost 2.00
    adult_meat 3.56
    payment_method "check"
  end
end