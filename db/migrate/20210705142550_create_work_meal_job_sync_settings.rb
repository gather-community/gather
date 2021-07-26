# frozen_string_literal: true

class CreateWorkMealJobSyncSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :work_meal_job_sync_settings do |t|
      t.references :formula, foreign_key: {to_table: :meal_formulas}, index: true, null: false
      t.references :role, foreign_key: {to_table: :meal_roles}, index: true, null: false
      t.references :period, foreign_key: {to_table: :work_periods}, index: true, null: false
      t.index %i[formula_id role_id period_id], unique: true, name: "work_meal_job_sync_settings_uniq"

      t.timestamps
    end
  end
end
