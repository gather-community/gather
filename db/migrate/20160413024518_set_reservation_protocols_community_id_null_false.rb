class SetReservationProtocolsCommunityIdNullFalse < ActiveRecord::Migration
  def change
    change_column_null :reservation_protocols, :community_id, false
  end
end
