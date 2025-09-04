# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_assignments
#
#  id                       :integer          not null, primary key
#  cluster_id               :integer          not null
#  cook_menu_reminder_count :integer          default(0), not null
#  created_at               :datetime         not null
#  meal_id                  :integer          not null
#  role_id                  :bigint           not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#
FactoryBot.define do
  factory :meal_assignment, class: "Meals::Assignment" do
    meal
    user
    association :role, factory: :meal_role
  end
end
