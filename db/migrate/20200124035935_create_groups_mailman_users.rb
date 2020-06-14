# frozen_string_literal: true

class CreateGroupsMailmanUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :group_mailman_users do |t|
      t.references :cluster, foreign_key: true, null: false, index: true
      t.bigint :user_id, null: false
      t.string :mailman_id, null: false
      t.index :user_id, unique: true
      t.index :mailman_id, unique: true
      t.timestamps
    end
    add_foreign_key :group_mailman_users, :users
  end
end
