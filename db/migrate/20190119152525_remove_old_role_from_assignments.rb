# frozen_string_literal: true

class RemoveOldRoleFromAssignments < ActiveRecord::Migration[5.1]
  def change
    remove_column :meal_assignments, :old_role, :string
  end
end
