# frozen_string_literal: true

module Work
  # Represents the user's desire to sync meal jobs for a given meal role in a given formula for a
# == Schema Information
#
# Table name: work_meal_job_sync_settings
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint
#  formula_id :bigint           not null
#  period_id  :bigint           not null
#  role_id    :bigint           not null
#
# Indexes
#
#  index_work_meal_job_sync_settings_on_cluster_id  (cluster_id)
#  index_work_meal_job_sync_settings_on_formula_id  (formula_id)
#  index_work_meal_job_sync_settings_on_period_id   (period_id)
#  index_work_meal_job_sync_settings_on_role_id     (role_id)
#  work_meal_job_sync_settings_uniq                 (formula_id,role_id,period_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (formula_id => meal_formulas.id)
#  fk_rails_...  (period_id => work_periods.id)
#  fk_rails_...  (role_id => meal_roles.id)
#
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
