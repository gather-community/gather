# frozen_string_literal: true

class CreateWorkReminderTemplates < ActiveRecord::Migration[5.1]
  def change
    create_table :work_reminder_templates do |t|
      t.integer "cluster_id", null: false
      t.integer "job_template_id", null: false
      t.string "note", limit: 256
      t.integer "rel_magnitude", null: false
      t.string "rel_unit_sign", null: false, limit: 16
      t.datetime "updated_at", null: false
      t.index %w[cluster_id job_template_id]
      t.timestamps
    end
    add_foreign_key "work_reminder_templates", "clusters"
    add_foreign_key "work_reminder_templates", "work_job_templates", column: "job_template_id"
  end
end
