# frozen_string_literal: true

class AddClusterIdToMealJobSyncSettings < ActiveRecord::Migration[6.0]
  def change
    add_reference :work_meal_job_sync_settings, :cluster, index: true, foreign_key: true
  end
end
