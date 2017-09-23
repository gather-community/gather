class AddPlateToPeopleVehicles < ActiveRecord::Migration
  def change
    add_column :people_vehicles, :plate, :string, limit: 10
  end
end
