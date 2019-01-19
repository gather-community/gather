# frozen_string_literal: true

class RenameAssignmentsTable < ActiveRecord::Migration[5.1]
  def change
    rename_table :assignments, :meal_assignments
  end
end
