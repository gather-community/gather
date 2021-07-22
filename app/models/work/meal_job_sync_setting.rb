# frozen_string_literal: true

module Work
  # Represents the user's desire to sync meal jobs for a given meal role in a given formula for a
  # given period.
  class MealJobSyncSetting < ApplicationRecord
    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :work_meal_job_sync_settings
    belongs_to :role, class_name: "Meals::Role", inverse_of: :work_meal_job_sync_settings
    belongs_to :period, class_name: "Work::Period", inverse_of: :meal_job_sync_settings

    attribute :selected, :boolean, default: true
    attribute :legacy, :boolean, default: false

    delegate :title, to: :role, prefix: true
  end
end
