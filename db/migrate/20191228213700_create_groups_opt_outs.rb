# frozen_string_literal: true

class CreateGroupsOptOuts < ActiveRecord::Migration[6.0]
  def change
    create_table :group_opt_outs do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :group, foreign_key: true, index: true, null: false
      t.references :user, foreign_key: true, index: true, null: false
      t.index %i[group_id user_id], unique: true

      t.timestamps
    end
  end
end
