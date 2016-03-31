class RemoveResourceIdFromProtocols < ActiveRecord::Migration
  def up
    remove_column :reservation_protocols, :resource_id
  end
end
