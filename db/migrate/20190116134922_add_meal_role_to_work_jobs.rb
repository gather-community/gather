# frozen_string_literal: true

class AddMealRoleToWorkJobs < ActiveRecord::Migration[5.1]
  def change
    add_reference :work_jobs, :meal_role, foreign_key: true, index: true
  end
end
