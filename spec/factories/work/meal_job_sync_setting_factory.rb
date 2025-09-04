# frozen_string_literal: true

# == Schema Information
#
# Table name: work_meal_job_sync_settings
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint
#  created_at :datetime         not null
#  formula_id :bigint           not null
#  period_id  :bigint           not null
#  role_id    :bigint           not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :work_meal_job_sync_setting, class: "Work::MealJobSyncSetting" do
    association :formula, factory: :meal_formula
    association :role, factory: :meal_role
    association :period, factory: :work_period
  end
end
