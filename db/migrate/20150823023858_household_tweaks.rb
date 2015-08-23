class HouseholdTweaks < ActiveRecord::Migration
  def change
    remove_column :households, :suffix, :string
    change_column_null :households, :unit_num, true
  end
end
