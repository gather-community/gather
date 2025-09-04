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
module Work
  # Represents the user's desire to sync meal jobs for a given meal role in a given formula for a
  # given period.
  class MealJobSyncSetting < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :work_meal_job_sync_settings
    belongs_to :role, class_name: "Meals::Role", inverse_of: :work_meal_job_sync_settings
    belongs_to :period, class_name: "Work::Period", inverse_of: :meal_job_sync_settings

    attribute :selected, :boolean, default: true
    attribute :legacy, :boolean, default: false

    delegate :title, to: :role, prefix: true

    def selected?
      self[:selected] && !marked_for_destruction?
    end
  end
end
