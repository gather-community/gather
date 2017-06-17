class AddPreWarningToReservationProtocols < ActiveRecord::Migration
  def change
    add_column :reservation_protocols, :pre_warning, :text
  end
end
