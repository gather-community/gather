class AddPreassignedToWorkAssignments < ActiveRecord::Migration[5.1]
  def change
    add_column :work_assignments, :preassigned, :boolean, default: false, null: false
  end
end
