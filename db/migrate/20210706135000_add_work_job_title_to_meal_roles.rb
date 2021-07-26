# frozen_string_literal: true

class AddWorkJobTitleToMealRoles < ActiveRecord::Migration[6.0]
  def change
    add_column :meal_roles, :work_job_title, :string, limit: 128
  end
end
