# frozen_string_literal: true

class AddIndexForDeactivatedAt < ActiveRecord::Migration[4.2]
  def change
    add_index :users, :deactivated_at
  end
end
