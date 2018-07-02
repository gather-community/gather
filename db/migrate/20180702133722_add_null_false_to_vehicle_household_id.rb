# frozen_string_literal: true

class AddNullFalseToVehicleHouseholdId < ActiveRecord::Migration[5.1]
  def change
    change_column_null :people_vehicles, :household_id, false
  end
end
