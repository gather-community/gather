class AddOldNameToHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :old_name, :string
    Household.update_all("old_name = name")
  end
end
