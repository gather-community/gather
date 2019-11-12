# frozen_string_literal: true

class CreateWorkAssignments < ActiveRecord::Migration[5.1]
  def change
    create_table :work_assignments do |t|
      t.integer :cluster_id, null: false
      t.integer :job_id, null: false
      t.integer :user_id, null: false

      t.timestamps
    end
    add_index :work_assignments, :cluster_id
    add_index :work_assignments, :job_id
    add_index :work_assignments, :user_id
    add_foreign_key :work_assignments, :clusters
    add_foreign_key :work_assignments, :work_jobs, column: "job_id"
    add_foreign_key :work_assignments, :users
  end
end
