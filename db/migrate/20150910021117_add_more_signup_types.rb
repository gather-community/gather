# frozen_string_literal: true

class AddMoreSignupTypes < ActiveRecord::Migration[4.2]
  def change
    rename_column :signups, :big_kid, :big_kid_meat
    rename_column :signups, :little_kid, :little_kid_meat
    add_column :signups, :big_kid_veg, :integer, default: 0, null: false
    add_column :signups, :little_kid_veg, :integer, default: 0, null: false
    add_column :signups, :senior_meat, :integer, default: 0, null: false
    add_column :signups, :senior_veg, :integer, default: 0, null: false
  end
end
