class AddOldNameToHouseholds < ActiveRecord::Migration
  def change
    add_column :households, :old_name, :string
    Household.update_all("old_name = name")
  end
end
