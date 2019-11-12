# frozen_string_literal: true

class RemoveVehiclesAndEmergencyContactsFromHouseholds < ActiveRecord::Migration[4.2]
  def change
    remove_column :households, :vehicles, :text
    remove_column :households, :emergency_contacts, :text
  end
end
