# frozen_string_literal: true

class AddUniqueIndexToWorkAssignments < ActiveRecord::Migration[5.1]
  def change
    add_index :work_assignments, %i[cluster_id shift_id user_id], unique: true
  end
end
