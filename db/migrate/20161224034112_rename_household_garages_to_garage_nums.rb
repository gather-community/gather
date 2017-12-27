class RenameHouseholdGaragesToGarageNums < ActiveRecord::Migration[4.2]
  def change
    rename_column :households, :garages, :garage_nums
  end
end
