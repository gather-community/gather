class RemoveResourceIdFromProtocols < ActiveRecord::Migration[4.2]
  def up
    remove_column :reservation_protocols, :resource_id
  end
end
