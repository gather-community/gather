class ChangeWorkAssignmentsToAssociateToShifts < ActiveRecord::Migration[5.1]
  def change
    drop_table :work_assignments
    create_table :work_assignments do |t|
      t.integer :cluster_id, null: false
      t.integer :shift_id, null: false
      t.integer :user_id, null: false

      t.timestamps
    end
    add_index :work_assignments, :cluster_id
    add_index :work_assignments, :shift_id
    add_index :work_assignments, :user_id
    add_foreign_key :work_assignments, :clusters
    add_foreign_key :work_assignments, :work_shifts, column: "shift_id"
    add_foreign_key :work_assignments, :users
  end
end
