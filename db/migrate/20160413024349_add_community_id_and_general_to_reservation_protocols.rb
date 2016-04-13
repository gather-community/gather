class AddCommunityIdAndGeneralToReservationProtocols < ActiveRecord::Migration
  def change
    add_reference :reservation_protocols, :community, index: true, foreign_key: true
    add_column :reservation_protocols, :general, :boolean, null: false, default: false
  end
end
