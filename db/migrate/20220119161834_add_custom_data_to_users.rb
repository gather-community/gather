# frozen_string_literal: true

class AddCustomDataToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :custom_data, :jsonb, default: {}, null: false
  end
end
