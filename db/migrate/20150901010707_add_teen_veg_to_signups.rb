class AddTeenVegToSignups < ActiveRecord::Migration
  def change
    add_column :signups, :teen_veg, :integer, default: 0, null: false
    rename_column :signups, :teen, :teen_meat
  end
end
