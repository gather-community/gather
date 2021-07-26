# frozen_string_literal: true

class AddWorkHoursToMealRoles < ActiveRecord::Migration[6.0]
  def change
    add_column :meal_roles, :work_hours, :decimal, precision: 6, scale: 2
  end
end
