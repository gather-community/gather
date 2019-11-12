# frozen_string_literal: true

class AddNotifiedToAssignments < ActiveRecord::Migration[4.2]
  def change
    add_column :assignments, :notified, :boolean, null: false, default: false
    add_index :assignments, :notified
  end
end
