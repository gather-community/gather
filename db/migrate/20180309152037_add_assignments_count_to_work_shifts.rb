# frozen_string_literal: true

class AddAssignmentsCountToWorkShifts < ActiveRecord::Migration[5.1]
  def change
    add_column :work_shifts, :assignments_count, :integer, null: false, default: 0
  end
end
