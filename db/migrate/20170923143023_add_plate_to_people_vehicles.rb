# frozen_string_literal: true

class AddPlateToPeopleVehicles < ActiveRecord::Migration[4.2]
  def change
    add_column :people_vehicles, :plate, :string, limit: 10
  end
end
