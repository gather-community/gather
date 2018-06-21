# frozen_string_literal: true

class CreateWorkReminders < ActiveRecord::Migration[5.1]
  def change
    create_table :work_reminders do |t|
      t.integer :cluster_id, null: false
      t.integer :job_id, null: false
      t.integer :rel_time
      t.datetime :abs_time
      t.string :note

      t.timestamps
    end
    add_foreign_key :work_reminders, :work_jobs, column: :job_id
    add_foreign_key :work_reminders, :clusters, column: :cluster_id
    add_index :work_reminders, %i[cluster_id job_id]
  end
end
