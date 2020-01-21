# frozen_string_literal: true

class CreateGroupMailmanLists < ActiveRecord::Migration[6.0]
  def change
    create_table :group_mailman_lists do |t|
      t.references :cluster, null: false, index: true, foreign_key: true
      t.string :name, index: true, null: false
      t.references :domain, null: false, index: true, foreign_key: true
      t.text :outside_members
      t.text :outside_senders
      t.index %w[name domain_id], unique: true

      t.timestamps
    end
  end
end
