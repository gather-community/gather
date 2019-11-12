# frozen_string_literal: true

class CreateWorkPeriods < ActiveRecord::Migration[5.1]
  def change
    create_table :work_periods do |t|
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :phase, null: false, default: "draft"
      t.integer :community_id, null: false
      t.integer :cluster_id, null: false

      t.timestamps
    end

    add_index :work_periods, :community_id
    add_index :work_periods, :cluster_id
    add_index :work_periods, %i[starts_on ends_on]
    add_foreign_key :work_periods, :communities
    add_foreign_key :work_periods, :clusters
  end
end
