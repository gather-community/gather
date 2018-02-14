class CreateWorkJobs < ActiveRecord::Migration[5.1]
  def change
    create_table :work_jobs do |t|
      t.integer :period_id, null: false
      t.string :title, null: false, limit: 128
      t.decimal :hours, null: false, precision: 6, scale: 2
      t.integer :requester_id
      t.string :times, null: false, default: "date_time", limit: 32
      t.string :shift_type, null: false, default: "normal", limit: 32
      t.text :description, limit: 64.kilobytes, null: false
      t.integer :community_id, null: false
      t.integer :cluster_id, null: false

      t.timestamps
    end

    add_index :work_jobs, :period_id
    add_index :work_jobs, :requester_id
    add_index :work_jobs, :community_id
    add_index :work_jobs, :cluster_id
    add_index :work_jobs, [:cluster_id, :community_id, :period_id, :title], unique: true,
      name: :index_work_jobs_title_unique

    add_foreign_key :work_jobs, :work_periods, column: "period_id"
    add_foreign_key :work_jobs, :people_groups, column: "requester_id"
    add_foreign_key :work_jobs, :communities
    add_foreign_key :work_jobs, :clusters
  end
end
