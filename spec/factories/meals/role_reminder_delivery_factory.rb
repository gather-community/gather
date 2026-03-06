# frozen_string_literal: true

FactoryBot.define do
  factory :meal_role_reminder_delivery, class: "Meals::RoleReminderDelivery" do
    association :reminder, factory: :meal_role_reminder
    meal
    deliver_at { 1.day.from_now }
  end
end
