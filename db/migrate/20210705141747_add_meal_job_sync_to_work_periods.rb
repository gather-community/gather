# frozen_string_literal: true

class AddMealJobSyncToWorkPeriods < ActiveRecord::Migration[6.0]
  def change
    add_column :work_periods, :meal_job_sync, :boolean, default: false, null: false
  end
end
