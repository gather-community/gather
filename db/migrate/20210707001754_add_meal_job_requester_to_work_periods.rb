# frozen_string_literal: true

class AddMealJobRequesterToWorkPeriods < ActiveRecord::Migration[6.0]
  def change
    add_reference :work_periods, :meal_job_requester, foreign_key: {to_table: :groups}, index: true
  end
end
