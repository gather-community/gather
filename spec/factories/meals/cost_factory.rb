# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_costs
#
#  id               :integer          not null, primary key
#  cluster_id       :integer          not null
#  created_at       :datetime         not null
#  ingredient_cost  :decimal(10, 2)   not null
#  meal_calc_type   :string
#  meal_id          :integer          not null
#  pantry_calc_type :string
#  pantry_cost      :decimal(10, 2)   not null
#  pantry_fee       :decimal(10, 2)
#  payment_method   :string           not null
#  reimbursee_id    :bigint
#  updated_at       :datetime         not null
#
FactoryBot.define do
  factory :meal_cost, class: "Meals::Cost" do
    meal
    association :reimbursee, factory: :user
    ingredient_cost { 10.00 }
    pantry_cost { 2.00 }
    payment_method { "check" }

    trait :with_parts do
      after(:build) do |cost|
        formula = cost.meal.formula
        cost.parts.build(type: formula.types.first, value: 3.56)
      end
    end
  end
end
