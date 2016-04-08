class AddRequiresKindToReservationProtocols < ActiveRecord::Migration
  def change
    add_column :reservation_protocols, :requires_kind, :boolean
  end
end
