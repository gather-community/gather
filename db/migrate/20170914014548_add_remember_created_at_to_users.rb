# frozen_string_literal: true

class AddRememberCreatedAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :remember_created_at, :datetime
  end
end
