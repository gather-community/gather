# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_formula_parts
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  formula_id   :bigint           not null
#  portion_size :decimal(10, 2)   not null
#  rank         :integer          not null
#  share        :decimal(10, 4)   not null
#  type_id      :bigint           not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :meal_formula_part, class: "Meals::FormulaPart" do
    association(:formula, factory: :meal_formula)
    association(:type, factory: :meal_type)
    share { 0.75 }
  end
end
