# frozen_string_literal: true

class CreateWorkJobTemplates < ActiveRecord::Migration[5.1]
  def change
    create_table :work_job_templates do |t|
      t.integer "cluster_id", null: false
      t.integer "community_id", null: false
      t.text "description", null: false
      t.boolean "double_signups_allowed", default: false
      t.decimal "hours", precision: 6, scale: 2, null: false
      t.integer "requester_id"
      t.string "time_type", limit: 32, default: "date_time", null: false
      t.string "title", limit: 128, null: false
      t.boolean "meal", null: false, default: false
      t.string "special", limit: 32
      t.integer "shift_start_offset"
      t.integer "shift_end_offset"
      t.index ["cluster_id"]
      t.index %w[community_id title], unique: true

      t.timestamps
    end

    add_foreign_key "work_job_templates", "clusters"
    add_foreign_key "work_job_templates", "communities"
  end
end
