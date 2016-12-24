class RenameHouseholdGaragesToGarageNums < ActiveRecord::Migration
  def change
    rename_column :households, :garages, :garage_nums
  end
end
