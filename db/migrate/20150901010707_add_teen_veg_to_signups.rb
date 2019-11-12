# frozen_string_literal: true

class AddTeenVegToSignups < ActiveRecord::Migration[4.2]
  def change
    add_column :signups, :teen_veg, :integer, default: 0, null: false
    rename_column :signups, :teen, :teen_meat
  end
end
