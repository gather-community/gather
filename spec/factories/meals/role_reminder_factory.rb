# frozen_string_literal: true

FactoryBot.define do
  factory :meal_role_reminder, class: "Meals::RoleReminder" do
    association :role, factory: :meal_role
    note { "Do stuff" }
    rel_unit_sign { "days_before" }
    rel_magnitude { 2 }
  end
end
