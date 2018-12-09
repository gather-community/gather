# frozen_string_literal: true

class RemoveUniqunessConstraintOnShiftsUsers < ActiveRecord::Migration[5.1]
  def change
    remove_index(:work_assignments, %w[cluster_id shift_id user_id])
    add_index(:work_assignments, %w[cluster_id shift_id user_id])
  end
end
