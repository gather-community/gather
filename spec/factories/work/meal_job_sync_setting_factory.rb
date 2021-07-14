# frozen_string_literal: true

FactoryBot.define do
  factory :work_meal_job_sync_setting, class: "Work::MealJobSyncSetting" do
    association :formula, factory: :meal_formula
    association :role, factory: :meal_role
    association :period, factory: :work_period
  end
end
