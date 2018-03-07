class CreateWorkShifts < ActiveRecord::Migration[5.1]
  def change
    create_table :work_shifts do |t|
      t.integer :job_id, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :slots, null: false

      t.timestamps
    end

    add_index :work_shifts, :job_id
    add_index :work_shifts, %i(job_id starts_at ends_at), unique: true

    add_foreign_key :work_shifts, :work_jobs, column: "job_id"
  end
end
