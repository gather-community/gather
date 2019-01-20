FactoryBot.define do
  factory :meal_assignment, class: "Meals::Assignment" do
    meal
    user
    association :role, factory: :meal_role
  end
end
