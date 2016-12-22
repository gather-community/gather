class RemoveVehiclesAndEmergencyContactsFromHouseholds < ActiveRecord::Migration
  def change
    remove_column :households, :vehicles, :text
    remove_column :households, :emergency_contacts, :text
  end
end
