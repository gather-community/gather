class SetReservationProtocolsCommunityIdNullFalse < ActiveRecord::Migration[4.2]
  def change
    change_column_null :reservation_protocols, :community_id, false
  end
end
