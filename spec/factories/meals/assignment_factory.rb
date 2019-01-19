FactoryBot.define do
  factory :assignment, class: "Meals::Assignment" do
    meal
    user
    old_role { "asst_cook" }
  end
end
